// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Layer2_HTLXTrigger
 * @notice Hashed Timelock Contract (HTLX) for conditional settlements
 * @dev Implements atomic swaps with timelock and hashlock mechanisms
 *
 * Features:
 * - Hashed Timelock for secure conditional transfers
 * - 60-day TLX recovery mechanism
 * - Multi-phase recovery with incentives
 * - Digital LC settlement automation
 *
 * @custom:security-contact security@htsdao.org
 * @custom:version 1.0.0
 */
contract Layer2_HTLXTrigger is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    // ============ Constants ============

    /// @notice 60-day recovery period (in seconds)
    uint256 public constant RECOVERY_PERIOD = 60 days;

    /// @notice Phase 1: Day 0-30 (high incentive)
    uint256 public constant PHASE1_DURATION = 30 days;

    /// @notice Phase 2: Day 31-45 (standard incentive)
    uint256 public constant PHASE2_DURATION = 15 days;

    /// @notice Phase 3: Day 46-60 (final window)
    uint256 public constant PHASE3_DURATION = 15 days;

    /// @notice Incentive multipliers (basis points: 10000 = 100%)
    uint256 public constant PHASE1_MULTIPLIER = 15000; // 1.5x
    uint256 public constant PHASE2_MULTIPLIER = 10000; // 1.0x
    uint256 public constant PHASE3_MULTIPLIER = 7000;  // 0.7x

    // ============ Enums ============

    enum AgreementStatus {
        PENDING,
        EXECUTED,
        REFUNDED,
        DISPUTED
    }

    enum RecoveryPhase {
        NONE,
        PHASE1, // Day 0-30
        PHASE2, // Day 31-45
        PHASE3, // Day 46-60
        EXPIRED // Post-60 days
    }

    // ============ Structs ============

    struct HTLXAgreement {
        bytes32 hashLock;           // Hash of secret
        uint256 timeLock;           // Expiry timestamp
        address sender;             // Payer address
        address receiver;           // Payee address
        address token;              // ERC20 token address (0x0 for native)
        uint256 amount;             // Locked amount
        AgreementStatus status;     // Current status
        uint256 createdAt;          // Creation timestamp
    }

    struct RecoveryPosition {
        address user;               // Liquidated user
        uint256 collateralValue;    // Original collateral value
        uint256 debtValue;          // Outstanding debt
        uint256 tlxAmount;          // TLX tokens minted
        uint256 liquidationTime;    // Liquidation timestamp
        RecoveryPhase phase;        // Current recovery phase
        bool recovered;             // Recovery status
    }

    // ============ State Variables ============

    /// @notice Agreement ID counter
    uint256 public agreementCounter;

    /// @notice HTLX agreements mapping
    mapping(bytes32 => HTLXAgreement) public agreements;

    /// @notice Recovery positions mapping
    mapping(address => RecoveryPosition) public recoveryPositions;

    /// @notice TLX token address (minted for recovery)
    address public tlxToken;

    /// @notice Layer1 feed address (for price validation)
    address public layer1Feed;

    // ============ Events ============

    event HTLXCreated(
        bytes32 indexed agreementId,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timeLock
    );

    event HTLXExecuted(
        bytes32 indexed agreementId,
        address indexed executor,
        bytes32 secret
    );

    event HTLXRefunded(
        bytes32 indexed agreementId,
        address indexed refundee
    );

    event HTLXDisputed(
        bytes32 indexed agreementId,
        address indexed disputant
    );

    event LiquidationExecuted(
        address indexed user,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 tlxMinted
    );

    event RecoveryPhaseUpdated(
        address indexed user,
        RecoveryPhase oldPhase,
        RecoveryPhase newPhase
    );

    event PositionRecovered(
        address indexed user,
        uint256 recoveryAmount,
        RecoveryPhase phase
    );

    // ============ Constructor ============

    /**
     * @notice Initialize HTLX Trigger contract
     * @param _layer1Feed Layer1 BLX Multi-RWA Feed address
     * @param _tlxToken TLX recovery token address
     * @param _admin Admin address
     */
    constructor(
        address _layer1Feed,
        address _tlxToken,
        address _admin
    ) {
        require(_layer1Feed != address(0), "Invalid Layer1 feed");
        require(_tlxToken != address(0), "Invalid TLX token");
        require(_admin != address(0), "Invalid admin");

        layer1Feed = _layer1Feed;
        tlxToken = _tlxToken;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _admin);
        _grantRole(LIQUIDATOR_ROLE, _admin);
    }

    // ============ HTLX Functions ============

    /**
     * @notice Create HTLX agreement (Letter of Credit settlement)
     * @param hashLock Hash of secret (keccak256)
     * @param timeLock Expiry timestamp (typically 30 days)
     * @param receiver Payee address
     * @param token ERC20 token address (address(0) for native token)
     * @param amount Locked amount
     * @return agreementId Unique agreement identifier
     */
    function createHTLX(
        bytes32 hashLock,
        uint256 timeLock,
        address receiver,
        address token,
        uint256 amount
    ) external payable nonReentrant returns (bytes32 agreementId) {
        require(hashLock != bytes32(0), "Invalid hash lock");
        require(timeLock > block.timestamp, "Invalid time lock");
        require(receiver != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        // Handle payment
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect native amount");
        } else {
            require(msg.value == 0, "No native token needed");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Generate agreement ID
        agreementId = keccak256(
            abi.encodePacked(
                msg.sender,
                receiver,
                amount,
                hashLock,
                block.timestamp,
                agreementCounter++
            )
        );

        // Store agreement
        agreements[agreementId] = HTLXAgreement({
            hashLock: hashLock,
            timeLock: timeLock,
            sender: msg.sender,
            receiver: receiver,
            token: token,
            amount: amount,
            status: AgreementStatus.PENDING,
            createdAt: block.timestamp
        });

        emit HTLXCreated(agreementId, msg.sender, receiver, amount, timeLock);

        return agreementId;
    }

    /**
     * @notice Execute HTLX agreement (reveal secret)
     * @param agreementId Agreement identifier
     * @param secret Secret that matches hash lock
     */
    function executeHTLX(bytes32 agreementId, bytes32 secret)
        external
        nonReentrant
    {
        HTLXAgreement storage agreement = agreements[agreementId];

        require(agreement.status == AgreementStatus.PENDING, "Not pending");
        require(block.timestamp < agreement.timeLock, "Time lock expired");
        require(
            keccak256(abi.encodePacked(secret)) == agreement.hashLock,
            "Invalid secret"
        );

        // Update status
        agreement.status = AgreementStatus.EXECUTED;

        // Transfer funds to receiver
        _transferFunds(
            agreement.token,
            agreement.receiver,
            agreement.amount
        );

        emit HTLXExecuted(agreementId, msg.sender, secret);
    }

    /**
     * @notice Refund HTLX agreement (after timelock expiry)
     * @param agreementId Agreement identifier
     */
    function refundHTLX(bytes32 agreementId) external nonReentrant {
        HTLXAgreement storage agreement = agreements[agreementId];

        require(agreement.status == AgreementStatus.PENDING, "Not pending");
        require(block.timestamp >= agreement.timeLock, "Time lock active");

        // Update status
        agreement.status = AgreementStatus.REFUNDED;

        // Transfer funds back to sender
        _transferFunds(
            agreement.token,
            agreement.sender,
            agreement.amount
        );

        emit HTLXRefunded(agreementId, agreement.sender);
    }

    /**
     * @notice Dispute HTLX agreement (requires admin intervention)
     * @param agreementId Agreement identifier
     */
    function disputeHTLX(bytes32 agreementId) external {
        HTLXAgreement storage agreement = agreements[agreementId];

        require(agreement.status == AgreementStatus.PENDING, "Not pending");
        require(
            msg.sender == agreement.sender || msg.sender == agreement.receiver,
            "Not authorized"
        );

        agreement.status = AgreementStatus.DISPUTED;

        emit HTLXDisputed(agreementId, msg.sender);
    }

    // ============ Liquidation Functions ============

    /**
     * @notice Execute liquidation and mint TLX tokens
     * @param user User address to liquidate
     * @param collateralValue Collateral value in USD
     * @param debtValue Debt value in USD
     */
    function executeLiquidation(
        address user,
        uint256 collateralValue,
        uint256 debtValue
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        require(user != address(0), "Invalid user");
        require(collateralValue > 0, "Invalid collateral");
        require(debtValue > 0, "Invalid debt");

        // Calculate TLX tokens to mint (proportional to debt)
        uint256 tlxAmount = debtValue; // 1:1 ratio for simplicity

        // Create recovery position
        recoveryPositions[user] = RecoveryPosition({
            user: user,
            collateralValue: collateralValue,
            debtValue: debtValue,
            tlxAmount: tlxAmount,
            liquidationTime: block.timestamp,
            phase: RecoveryPhase.PHASE1, // Start in Phase 1
            recovered: false
        });

        // Mint TLX tokens to user (requires TLX contract to grant mint role)
        // IERC20Mintable(tlxToken).mint(user, tlxAmount);

        emit LiquidationExecuted(user, collateralValue, debtValue, tlxAmount);
    }

    // ============ Recovery Functions ============

    /**
     * @notice Get current recovery phase for user
     * @param user User address
     * @return phase Current recovery phase
     */
    function getCurrentPhase(address user) public view returns (RecoveryPhase phase) {
        RecoveryPosition memory position = recoveryPositions[user];

        if (position.liquidationTime == 0 || position.recovered) {
            return RecoveryPhase.NONE;
        }

        uint256 elapsed = block.timestamp - position.liquidationTime;

        if (elapsed <= PHASE1_DURATION) {
            return RecoveryPhase.PHASE1;
        } else if (elapsed <= PHASE1_DURATION + PHASE2_DURATION) {
            return RecoveryPhase.PHASE2;
        } else if (elapsed <= RECOVERY_PERIOD) {
            return RecoveryPhase.PHASE3;
        } else {
            return RecoveryPhase.EXPIRED;
        }
    }

    /**
     * @notice Calculate recovery amount based on phase
     * @param user User address
     * @return recoveryAmount Amount user can recover (with incentive)
     * @return incentiveMultiplier Current incentive multiplier (basis points)
     */
    function calculateRecoveryAmount(address user)
        public
        view
        returns (uint256 recoveryAmount, uint256 incentiveMultiplier)
    {
        RecoveryPosition memory position = recoveryPositions[user];
        RecoveryPhase currentPhase = getCurrentPhase(user);

        if (currentPhase == RecoveryPhase.NONE || currentPhase == RecoveryPhase.EXPIRED) {
            return (0, 0);
        }

        // Get incentive multiplier
        if (currentPhase == RecoveryPhase.PHASE1) {
            incentiveMultiplier = PHASE1_MULTIPLIER;
        } else if (currentPhase == RecoveryPhase.PHASE2) {
            incentiveMultiplier = PHASE2_MULTIPLIER;
        } else {
            incentiveMultiplier = PHASE3_MULTIPLIER;
        }

        // Calculate recovery amount: debt + (incentive * collateral_surplus)
        uint256 surplus = position.collateralValue > position.debtValue
            ? position.collateralValue - position.debtValue
            : 0;

        recoveryAmount = position.debtValue + ((surplus * incentiveMultiplier) / 10000);

        return (recoveryAmount, incentiveMultiplier);
    }

    /**
     * @notice Claim recovery using TLX tokens
     * @dev User must repay debt + premium using TLX tokens
     */
    function claimRecovery() external nonReentrant {
        address user = msg.sender;
        RecoveryPosition storage position = recoveryPositions[user];

        require(position.liquidationTime > 0, "No recovery position");
        require(!position.recovered, "Already recovered");

        RecoveryPhase currentPhase = getCurrentPhase(user);
        require(currentPhase != RecoveryPhase.NONE, "Invalid phase");
        require(currentPhase != RecoveryPhase.EXPIRED, "Recovery expired");

        (uint256 recoveryAmount, uint256 incentiveMultiplier) = calculateRecoveryAmount(user);

        // Burn TLX tokens from user
        IERC20(tlxToken).safeTransferFrom(user, address(this), position.tlxAmount);
        // IERC20Burnable(tlxToken).burn(position.tlxAmount);

        // Mark as recovered
        position.recovered = true;

        emit PositionRecovered(user, recoveryAmount, currentPhase);
    }

    // ============ Internal Functions ============

    /**
     * @notice Internal function to transfer funds (native or ERC20)
     */
    function _transferFunds(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get HTLX agreement details
     */
    function getHTLXStatus(bytes32 agreementId)
        external
        view
        returns (HTLXAgreement memory)
    {
        return agreements[agreementId];
    }

    /**
     * @notice Get recovery position details
     */
    function getRecoveryPosition(address user)
        external
        view
        returns (RecoveryPosition memory)
    {
        return recoveryPositions[user];
    }

    /**
     * @notice Check if timelock is expired
     */
    function isTimelockExpired(bytes32 agreementId) public view returns (bool) {
        HTLXAgreement memory agreement = agreements[agreementId];
        return block.timestamp >= agreement.timeLock;
    }

    // ============ Admin Functions ============

    /**
     * @notice Resolve disputed agreement (admin only)
     */
    function resolveDispute(
        bytes32 agreementId,
        bool favorReceiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        HTLXAgreement storage agreement = agreements[agreementId];
        require(agreement.status == AgreementStatus.DISPUTED, "Not disputed");

        if (favorReceiver) {
            agreement.status = AgreementStatus.EXECUTED;
            _transferFunds(agreement.token, agreement.receiver, agreement.amount);
        } else {
            agreement.status = AgreementStatus.REFUNDED;
            _transferFunds(agreement.token, agreement.sender, agreement.amount);
        }
    }

    /**
     * @notice Update TLX token address (admin only)
     */
    function setTLXToken(address _tlxToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tlxToken != address(0), "Invalid TLX token");
        tlxToken = _tlxToken;
    }

    /**
     * @notice Emergency withdraw (admin only)
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _transferFunds(token, to, amount);
    }

    // ============ Receive Function ============

    receive() external payable {}
}
