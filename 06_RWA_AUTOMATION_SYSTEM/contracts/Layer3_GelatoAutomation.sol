// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Layer3_GelatoAutomation
 * @notice Gelato Network integration for automated liquidation monitoring
 * @dev Implements checker pattern for off-chain keeper automation
 *
 * Features:
 * - 12-second monitoring cycle via Gelato keepers
 * - Multi-condition evaluation (Timelock, LTV, Price)
 * - Automated liquidation execution
 * - Gas-optimized checker function
 * - Emergency pause mechanism
 *
 * @custom:security-contact security@htsdao.org
 * @custom:version 1.0.0
 */
contract Layer3_GelatoAutomation is ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // ============ Interfaces ============

    interface ILayer1BLXFeed {
        function calculateLTV(address user) external view returns (uint256);
        function isLiquidatable(address user) external view returns (bool);
        function getUserPosition(address user) external view returns (
            uint256 collateralValue,
            uint256 debtValue,
            uint256 ltv,
            bool isActive,
            uint256 lastUpdate
        );
    }

    interface ILayer2HTLX {
        function executeLiquidation(
            address user,
            uint256 collateralValue,
            uint256 debtValue
        ) external;
        function isTimelockExpired(bytes32 agreementId) external view returns (bool);
    }

    // ============ State Variables ============

    /// @notice Layer1 BLX Multi-RWA Feed contract
    ILayer1BLXFeed public layer1Feed;

    /// @notice Layer2 HTLX Trigger contract
    ILayer2HTLX public layer2HTLX;

    /// @notice LTV liquidation threshold (125%)
    uint256 public constant LTV_THRESHOLD = 125;

    /// @notice Maximum users to check per cycle (gas limit)
    uint256 public constant MAX_BATCH_SIZE = 10;

    /// @notice Minimum time between liquidations per user (5 minutes)
    uint256 public constant LIQUIDATION_COOLDOWN = 5 minutes;

    /// @notice User registry (active positions)
    address[] public activeUsers;
    mapping(address => bool) public isActiveUser;
    mapping(address => uint256) public userIndex;

    /// @notice Liquidation tracking
    mapping(address => uint256) public lastLiquidation;
    mapping(address => bool) public isLiquidating;

    /// @notice Statistics
    uint256 public totalLiquidations;
    uint256 public totalChecks;
    uint256 public lastCheckTimestamp;

    // ============ Events ============

    event CheckerExecuted(
        uint256 indexed checkId,
        uint256 timestamp,
        uint256 gasUsed,
        bool conditionMet
    );

    event LiquidationTriggered(
        address indexed user,
        uint256 ltv,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 timestamp
    );

    event LiquidationExecuted(
        address indexed user,
        uint256 timestamp,
        uint256 gasUsed
    );

    event UserAdded(address indexed user);
    event UserRemoved(address indexed user);

    event EmergencyPause(address indexed admin, uint256 timestamp);
    event EmergencyUnpause(address indexed admin, uint256 timestamp);

    // ============ Constructor ============

    /**
     * @notice Initialize Gelato Automation contract
     * @param _layer1Feed Layer1 BLX Multi-RWA Feed address
     * @param _layer2HTLX Layer2 HTLX Trigger address
     * @param _gelatoExecutor Gelato executor address
     * @param _admin Admin address
     */
    constructor(
        address _layer1Feed,
        address _layer2HTLX,
        address _gelatoExecutor,
        address _admin
    ) {
        require(_layer1Feed != address(0), "Invalid Layer1");
        require(_layer2HTLX != address(0), "Invalid Layer2");
        require(_gelatoExecutor != address(0), "Invalid executor");
        require(_admin != address(0), "Invalid admin");

        layer1Feed = ILayer1BLXFeed(_layer1Feed);
        layer2HTLX = ILayer2HTLX(_layer2HTLX);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _gelatoExecutor);
        _grantRole(KEEPER_ROLE, _gelatoExecutor);
    }

    // ============ Gelato Checker Function ============

    /**
     * @notice Main checker function called by Gelato keepers every 12 seconds
     * @dev This is a VIEW function (zero gas cost for off-chain calls)
     * @return canExec True if liquidation conditions are met
     * @return execPayload Encoded function call to execute
     *
     * Gas Optimization:
     * - Early returns to minimize computation
     * - Batch size limit to prevent out-of-gas
     * - View function (no state changes)
     */
    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 gasStart = gasleft();

        // Safety check: contract not paused
        if (paused()) {
            return (false, bytes("Contract paused"));
        }

        // Check active users for liquidation conditions
        uint256 usersToCheck = activeUsers.length > MAX_BATCH_SIZE
            ? MAX_BATCH_SIZE
            : activeUsers.length;

        for (uint256 i = 0; i < usersToCheck; i++) {
            address user = activeUsers[i];

            // Skip if already liquidating
            if (isLiquidating[user]) continue;

            // Skip if cooldown active
            if (block.timestamp < lastLiquidation[user] + LIQUIDATION_COOLDOWN) {
                continue;
            }

            // Check if user is liquidatable (LTV > 125%)
            bool shouldLiquidate = layer1Feed.isLiquidatable(user);

            if (shouldLiquidate) {
                // Get position details
                (
                    uint256 collateralValue,
                    uint256 debtValue,
                    uint256 ltv,
                    bool isActive,

                ) = layer1Feed.getUserPosition(user);

                // Validate position
                if (!isActive || ltv <= LTV_THRESHOLD) continue;

                // Build execution payload
                execPayload = abi.encodeWithSelector(
                    this.executeLiquidation.selector,
                    user,
                    collateralValue,
                    debtValue,
                    ltv
                );

                // Condition met - return immediately
                return (true, execPayload);
            }
        }

        // No conditions met
        return (false, bytes("No liquidations needed"));
    }

    /**
     * @notice Alternative checker for batch liquidations
     * @dev Returns multiple users to liquidate in one transaction
     */
    function checkerBatch()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        if (paused()) {
            return (false, bytes("Contract paused"));
        }

        address[] memory usersToLiquidate = new address[](MAX_BATCH_SIZE);
        uint256[] memory ltvs = new uint256[](MAX_BATCH_SIZE);
        uint256 count = 0;

        uint256 usersToCheck = activeUsers.length > MAX_BATCH_SIZE
            ? MAX_BATCH_SIZE
            : activeUsers.length;

        for (uint256 i = 0; i < usersToCheck && count < MAX_BATCH_SIZE; i++) {
            address user = activeUsers[i];

            if (isLiquidating[user]) continue;
            if (block.timestamp < lastLiquidation[user] + LIQUIDATION_COOLDOWN) continue;

            if (layer1Feed.isLiquidatable(user)) {
                usersToLiquidate[count] = user;
                ltvs[count] = layer1Feed.calculateLTV(user);
                count++;
            }
        }

        if (count == 0) {
            return (false, bytes("No liquidations needed"));
        }

        // Trim arrays
        address[] memory users = new address[](count);
        uint256[] memory userLtvs = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            users[i] = usersToLiquidate[i];
            userLtvs[i] = ltvs[i];
        }

        execPayload = abi.encodeWithSelector(
            this.executeBatchLiquidation.selector,
            users,
            userLtvs
        );

        return (true, execPayload);
    }

    // ============ Liquidation Execution Functions ============

    /**
     * @notice Execute single liquidation (called by Gelato keeper)
     * @param user User address to liquidate
     * @param collateralValue Collateral value (from checker)
     * @param debtValue Debt value (from checker)
     * @param ltv Current LTV (from checker)
     */
    function executeLiquidation(
        address user,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 ltv
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(EXECUTOR_ROLE)
    {
        uint256 gasStart = gasleft();

        require(user != address(0), "Invalid user");
        require(!isLiquidating[user], "Already liquidating");
        require(ltv > LTV_THRESHOLD, "LTV below threshold");

        // Mark as liquidating (prevent race conditions)
        isLiquidating[user] = true;

        // Verify LTV still exceeds threshold (freshness check)
        uint256 currentLTV = layer1Feed.calculateLTV(user);
        require(currentLTV > LTV_THRESHOLD, "LTV normalized");

        // Update tracking
        lastLiquidation[user] = block.timestamp;
        totalLiquidations++;

        // Execute liquidation via Layer2
        layer2HTLX.executeLiquidation(user, collateralValue, debtValue);

        // Reset liquidating flag
        isLiquidating[user] = false;

        // Remove from active users (position closed)
        _removeUser(user);

        emit LiquidationTriggered(user, ltv, collateralValue, debtValue, block.timestamp);
        emit LiquidationExecuted(user, block.timestamp, gasStart - gasleft());
    }

    /**
     * @notice Execute batch liquidations (multiple users)
     * @param users Array of user addresses
     * @param ltvs Array of corresponding LTVs
     */
    function executeBatchLiquidation(
        address[] calldata users,
        uint256[] calldata ltvs
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(EXECUTOR_ROLE)
    {
        require(users.length == ltvs.length, "Length mismatch");
        require(users.length <= MAX_BATCH_SIZE, "Batch too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 ltv = ltvs[i];

            if (isLiquidating[user] || ltv <= LTV_THRESHOLD) {
                continue; // Skip invalid users
            }

            // Get position details
            (
                uint256 collateralValue,
                uint256 debtValue,
                ,
                bool isActive,

            ) = layer1Feed.getUserPosition(user);

            if (!isActive) continue;

            // Mark and execute
            isLiquidating[user] = true;
            lastLiquidation[user] = block.timestamp;
            totalLiquidations++;

            layer2HTLX.executeLiquidation(user, collateralValue, debtValue);

            isLiquidating[user] = false;
            _removeUser(user);

            emit LiquidationTriggered(user, ltv, collateralValue, debtValue, block.timestamp);
        }
    }

    // ============ User Registry Functions ============

    /**
     * @notice Add user to active monitoring list
     * @param user User address
     */
    function addUser(address user) external onlyRole(KEEPER_ROLE) {
        require(user != address(0), "Invalid user");
        require(!isActiveUser[user], "Already active");

        activeUsers.push(user);
        isActiveUser[user] = true;
        userIndex[user] = activeUsers.length - 1;

        emit UserAdded(user);
    }

    /**
     * @notice Add multiple users to monitoring list
     * @param users Array of user addresses
     */
    function addUsersBatch(address[] calldata users) external onlyRole(KEEPER_ROLE) {
        for (uint256 i = 0; i < users.length; i++) {
            if (!isActiveUser[users[i]] && users[i] != address(0)) {
                activeUsers.push(users[i]);
                isActiveUser[users[i]] = true;
                userIndex[users[i]] = activeUsers.length - 1;
                emit UserAdded(users[i]);
            }
        }
    }

    /**
     * @notice Remove user from monitoring list (internal)
     */
    function _removeUser(address user) internal {
        if (!isActiveUser[user]) return;

        uint256 index = userIndex[user];
        uint256 lastIndex = activeUsers.length - 1;

        if (index != lastIndex) {
            address lastUser = activeUsers[lastIndex];
            activeUsers[index] = lastUser;
            userIndex[lastUser] = index;
        }

        activeUsers.pop();
        delete isActiveUser[user];
        delete userIndex[user];

        emit UserRemoved(user);
    }

    /**
     * @notice Remove user from monitoring list (admin)
     */
    function removeUser(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeUser(user);
    }

    // ============ View Functions ============

    /**
     * @notice Get active users count
     */
    function getActiveUsersCount() external view returns (uint256) {
        return activeUsers.length;
    }

    /**
     * @notice Get active users list (paginated)
     */
    function getActiveUsers(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory users)
    {
        require(offset < activeUsers.length, "Invalid offset");

        uint256 end = offset + limit;
        if (end > activeUsers.length) {
            end = activeUsers.length;
        }

        uint256 length = end - offset;
        users = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            users[i] = activeUsers[offset + i];
        }

        return users;
    }

    /**
     * @notice Get liquidation statistics
     */
    function getStats()
        external
        view
        returns (
            uint256 activeCount,
            uint256 liquidationCount,
            uint256 checkCount,
            uint256 lastCheck
        )
    {
        return (
            activeUsers.length,
            totalLiquidations,
            totalChecks,
            lastCheckTimestamp
        );
    }

    // ============ Admin Functions ============

    /**
     * @notice Emergency pause (stops all liquidations)
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender, block.timestamp);
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit EmergencyUnpause(msg.sender, block.timestamp);
    }

    /**
     * @notice Update Layer1 feed address
     */
    function setLayer1Feed(address _layer1Feed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_layer1Feed != address(0), "Invalid address");
        layer1Feed = ILayer1BLXFeed(_layer1Feed);
    }

    /**
     * @notice Update Layer2 HTLX address
     */
    function setLayer2HTLX(address _layer2HTLX) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_layer2HTLX != address(0), "Invalid address");
        layer2HTLX = ILayer2HTLX(_layer2HTLX);
    }

    /**
     * @notice Add Gelato executor
     */
    function addExecutor(address executor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(EXECUTOR_ROLE, executor);
        grantRole(KEEPER_ROLE, executor);
    }

    /**
     * @notice Remove Gelato executor
     */
    function removeExecutor(address executor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(EXECUTOR_ROLE, executor);
        revokeRole(KEEPER_ROLE, executor);
    }

    /**
     * @notice Manually trigger liquidation (emergency use)
     */
    function manualLiquidation(address user)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(layer1Feed.isLiquidatable(user), "Not liquidatable");

        (
            uint256 collateralValue,
            uint256 debtValue,
            uint256 ltv,
            ,

        ) = layer1Feed.getUserPosition(user);

        isLiquidating[user] = true;
        layer2HTLX.executeLiquidation(user, collateralValue, debtValue);
        isLiquidating[user] = false;

        emit LiquidationTriggered(user, ltv, collateralValue, debtValue, block.timestamp);
    }
}
