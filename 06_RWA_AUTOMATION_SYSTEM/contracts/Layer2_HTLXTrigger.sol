// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IBLXMultiRWAFeed {
    function getBasketValue() external view returns (uint256);
    function getAssetBreakdown() external view returns (
        uint256 usTreasuries,
        uint256 privateCredit,
        uint256 gold,
        uint256 total
    );
}

/**
 * @title HTLXTrigger
 * @notice Layer 2: LTV Calculator and Trigger Logic with 60-day Timelock
 * @dev Monitors LTV ratio and triggers actions when thresholds are breached
 */
contract HTLXTrigger is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // LTV Configuration
    uint256 public constant TARGET_LTV = 12000; // 120% in basis points
    uint256 public constant TRIGGER_LTV = 12500; // 125% in basis points
    uint256 public constant CRITICAL_LTV = 13000; // 130% in basis points
    uint256 public constant BASIS_POINTS = 10000;

    // Timelock Configuration
    uint256 public constant TIMELOCK_DURATION = 60 days;
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 90 days;

    struct LoanPosition {
        uint256 collateralValue;  // Current collateral value in USD
        uint256 loanAmount;       // Outstanding loan amount in USD
        uint256 timestamp;        // Last update timestamp
        bool isActive;            // Position status
        address borrower;         // Borrower address
    }

    struct TriggerEvent {
        uint256 triggerId;        // Unique trigger ID
        uint256 loanId;          // Associated loan ID
        uint256 ltvRatio;        // LTV at trigger time
        uint256 timestamp;       // Trigger timestamp
        uint256 executionTime;   // Execution time (timestamp + timelock)
        bool isExecuted;         // Execution status
        bool isCancelled;        // Cancellation status
        TriggerType triggerType; // Type of trigger
    }

    enum TriggerType {
        WARNING,           // LTV > Target (120%)
        LIQUIDATION_PREP,  // LTV > Trigger (125%)
        CRITICAL           // LTV > Critical (130%)
    }

    // Storage
    IBLXMultiRWAFeed public blxFeed;

    mapping(uint256 => LoanPosition) public loans;
    mapping(uint256 => TriggerEvent) public triggers;
    mapping(uint256 => uint256[]) public loanTriggers; // loanId => triggerIds[]

    uint256 public loanCount;
    uint256 public triggerCount;

    // Timelock queue
    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 collateralValue,
        uint256 loanAmount
    );

    event LTVCalculated(
        uint256 indexed loanId,
        uint256 ltvRatio,
        uint256 collateralValue,
        uint256 loanAmount,
        uint256 timestamp
    );

    event TriggerActivated(
        uint256 indexed triggerId,
        uint256 indexed loanId,
        uint256 ltvRatio,
        TriggerType triggerType,
        uint256 executionTime
    );

    event TriggerExecuted(
        uint256 indexed triggerId,
        uint256 indexed loanId,
        bool success
    );

    event TriggerCancelled(
        uint256 indexed triggerId,
        uint256 indexed loanId
    );

    event TimelockQueued(
        bytes32 indexed txHash,
        uint256 indexed triggerId,
        uint256 executionTime
    );

    constructor(address _blxFeed) {
        require(_blxFeed != address(0), "Invalid BLX feed address");
        blxFeed = IBLXMultiRWAFeed(_blxFeed);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Create a new loan position
     * @param borrower Borrower address
     * @param loanAmount Loan amount in USD (18 decimals)
     */
    function createLoan(
        address borrower,
        uint256 loanAmount
    ) external onlyRole(MANAGER_ROLE) returns (uint256) {
        require(borrower != address(0), "Invalid borrower");
        require(loanAmount > 0, "Invalid loan amount");

        uint256 collateralValue = blxFeed.getBasketValue();
        require(collateralValue > 0, "No collateral value");

        uint256 loanId = loanCount++;

        loans[loanId] = LoanPosition({
            collateralValue: collateralValue,
            loanAmount: loanAmount,
            timestamp: block.timestamp,
            isActive: true,
            borrower: borrower
        });

        emit LoanCreated(loanId, borrower, collateralValue, loanAmount);

        // Check LTV immediately
        _checkAndTriggerLTV(loanId);

        return loanId;
    }

    /**
     * @notice Calculate current LTV ratio
     * @param loanId Loan ID
     * @return LTV ratio in basis points
     */
    function calculateLTV(uint256 loanId) public view returns (uint256) {
        LoanPosition memory loan = loans[loanId];
        require(loan.isActive, "Loan not active");

        uint256 currentCollateralValue = blxFeed.getBasketValue();

        if (currentCollateralValue == 0) {
            return type(uint256).max; // Infinite LTV if no collateral
        }

        // LTV = (Loan Amount / Collateral Value) * 10000
        return (loan.loanAmount * BASIS_POINTS) / currentCollateralValue;
    }

    /**
     * @notice Update loan collateral value
     * @param loanId Loan ID
     */
    function updateCollateral(uint256 loanId) external onlyRole(KEEPER_ROLE) {
        require(loans[loanId].isActive, "Loan not active");

        uint256 currentCollateralValue = blxFeed.getBasketValue();
        loans[loanId].collateralValue = currentCollateralValue;
        loans[loanId].timestamp = block.timestamp;

        uint256 ltvRatio = calculateLTV(loanId);

        emit LTVCalculated(
            loanId,
            ltvRatio,
            currentCollateralValue,
            loans[loanId].loanAmount,
            block.timestamp
        );

        _checkAndTriggerLTV(loanId);
    }

    /**
     * @notice Check LTV and trigger if necessary
     * @param loanId Loan ID
     */
    function _checkAndTriggerLTV(uint256 loanId) internal {
        uint256 ltvRatio = calculateLTV(loanId);
        TriggerType triggerType;
        bool shouldTrigger = false;

        if (ltvRatio >= CRITICAL_LTV) {
            triggerType = TriggerType.CRITICAL;
            shouldTrigger = true;
        } else if (ltvRatio >= TRIGGER_LTV) {
            triggerType = TriggerType.LIQUIDATION_PREP;
            shouldTrigger = true;
        } else if (ltvRatio >= TARGET_LTV) {
            triggerType = TriggerType.WARNING;
            shouldTrigger = true;
        }

        if (shouldTrigger) {
            _activateTrigger(loanId, ltvRatio, triggerType);
        }
    }

    /**
     * @notice Activate trigger with timelock
     * @param loanId Loan ID
     * @param ltvRatio Current LTV ratio
     * @param triggerType Type of trigger
     */
    function _activateTrigger(
        uint256 loanId,
        uint256 ltvRatio,
        TriggerType triggerType
    ) internal {
        uint256 triggerId = triggerCount++;
        uint256 executionTime = block.timestamp + TIMELOCK_DURATION;

        triggers[triggerId] = TriggerEvent({
            triggerId: triggerId,
            loanId: loanId,
            ltvRatio: ltvRatio,
            timestamp: block.timestamp,
            executionTime: executionTime,
            isExecuted: false,
            isCancelled: false,
            triggerType: triggerType
        });

        loanTriggers[loanId].push(triggerId);

        // Queue in timelock
        bytes32 txHash = keccak256(
            abi.encode(triggerId, loanId, ltvRatio, executionTime)
        );
        queuedTransactions[txHash] = true;

        emit TriggerActivated(
            triggerId,
            loanId,
            ltvRatio,
            triggerType,
            executionTime
        );

        emit TimelockQueued(txHash, triggerId, executionTime);
    }

    /**
     * @notice Execute trigger after timelock
     * @param triggerId Trigger ID
     */
    function executeTrigger(
        uint256 triggerId
    ) external onlyRole(KEEPER_ROLE) nonReentrant returns (bool) {
        TriggerEvent storage trigger = triggers[triggerId];

        require(!trigger.isExecuted, "Already executed");
        require(!trigger.isCancelled, "Trigger cancelled");
        require(
            block.timestamp >= trigger.executionTime,
            "Timelock not expired"
        );

        bytes32 txHash = keccak256(
            abi.encode(
                triggerId,
                trigger.loanId,
                trigger.ltvRatio,
                trigger.executionTime
            )
        );
        require(queuedTransactions[txHash], "Not queued");

        trigger.isExecuted = true;
        queuedTransactions[txHash] = false;

        emit TriggerExecuted(triggerId, trigger.loanId, true);

        return true;
    }

    /**
     * @notice Cancel trigger before execution
     * @param triggerId Trigger ID
     */
    function cancelTrigger(
        uint256 triggerId
    ) external onlyRole(MANAGER_ROLE) {
        TriggerEvent storage trigger = triggers[triggerId];

        require(!trigger.isExecuted, "Already executed");
        require(!trigger.isCancelled, "Already cancelled");

        trigger.isCancelled = true;

        bytes32 txHash = keccak256(
            abi.encode(
                triggerId,
                trigger.loanId,
                trigger.ltvRatio,
                trigger.executionTime
            )
        );
        queuedTransactions[txHash] = false;

        emit TriggerCancelled(triggerId, trigger.loanId);
    }

    /**
     * @notice Get loan triggers
     * @param loanId Loan ID
     */
    function getLoanTriggers(
        uint256 loanId
    ) external view returns (uint256[] memory) {
        return loanTriggers[loanId];
    }

    /**
     * @notice Check if trigger is ready for execution
     * @param triggerId Trigger ID
     */
    function canExecuteTrigger(uint256 triggerId) public view returns (bool) {
        TriggerEvent memory trigger = triggers[triggerId];

        return (
            !trigger.isExecuted &&
            !trigger.isCancelled &&
            block.timestamp >= trigger.executionTime
        );
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @notice Add keeper
     */
    function addKeeper(address keeper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(KEEPER_ROLE, keeper);
    }

    /**
     * @notice Remove keeper
     */
    function removeKeeper(address keeper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(KEEPER_ROLE, keeper);
    }
}
