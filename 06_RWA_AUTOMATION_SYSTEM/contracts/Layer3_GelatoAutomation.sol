// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IHTLXTrigger {
    function calculateLTV(uint256 loanId) external view returns (uint256);
    function updateCollateral(uint256 loanId) external;
    function executeTrigger(uint256 triggerId) external returns (bool);
    function canExecuteTrigger(uint256 triggerId) external view returns (bool);
}

/**
 * @title GelatoAutomation
 * @notice Layer 3: Gelato Keeper Integration for Automated Monitoring
 * @dev Monitors conditions and executes triggers automatically
 */
contract GelatoAutomation is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GELATO_ROLE = keccak256("GELATO_ROLE");

    IHTLXTrigger public htlxTrigger;

    // Monitoring configuration
    uint256 public constant TARGET_SETTLEMENT_TIME = 60; // 60 seconds
    uint256 public monitoringInterval = 5 minutes;
    uint256 public maxGasPrice = 100 gwei;

    struct MonitorTask {
        uint256 taskId;
        uint256 loanId;
        bool isActive;
        uint256 lastCheck;
        uint256 checkCount;
        uint256 executionCount;
    }

    struct ExecutionMetrics {
        uint256 totalExecutions;
        uint256 successfulExecutions;
        uint256 failedExecutions;
        uint256 averageExecutionTime;
        uint256 lastExecutionTime;
    }

    // Storage
    mapping(uint256 => MonitorTask) public monitorTasks;
    mapping(uint256 => uint256[]) public loanMonitors; // loanId => taskIds[]
    mapping(uint256 => ExecutionMetrics) public taskMetrics;

    uint256 public taskCount;

    // Events
    event TaskCreated(
        uint256 indexed taskId,
        uint256 indexed loanId,
        uint256 timestamp
    );

    event ConditionChecked(
        uint256 indexed taskId,
        uint256 indexed loanId,
        bool shouldExecute,
        uint256 timestamp
    );

    event TaskExecuted(
        uint256 indexed taskId,
        uint256 indexed triggerId,
        bool success,
        uint256 executionTime,
        uint256 gasUsed
    );

    event TaskDeactivated(
        uint256 indexed taskId,
        uint256 indexed loanId
    );

    constructor(address _htlxTrigger) {
        require(_htlxTrigger != address(0), "Invalid HTLX address");
        htlxTrigger = IHTLXTrigger(_htlxTrigger);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Create monitoring task for a loan
     * @param loanId Loan ID to monitor
     */
    function createMonitorTask(
        uint256 loanId
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        uint256 taskId = taskCount++;

        monitorTasks[taskId] = MonitorTask({
            taskId: taskId,
            loanId: loanId,
            isActive: true,
            lastCheck: block.timestamp,
            checkCount: 0,
            executionCount: 0
        });

        loanMonitors[loanId].push(taskId);

        emit TaskCreated(taskId, loanId, block.timestamp);

        return taskId;
    }

    /**
     * @notice Gelato-compatible checker function
     * @param taskId Task ID to check
     * @return canExec Whether task can be executed
     * @return execPayload Execution payload
     */
    function checker(
        uint256 taskId
    ) external view returns (bool canExec, bytes memory execPayload) {
        MonitorTask memory task = monitorTasks[taskId];

        if (!task.isActive) {
            return (false, bytes("Task not active"));
        }

        if (block.timestamp < task.lastCheck + monitoringInterval) {
            return (false, bytes("Monitoring interval not passed"));
        }

        // Check LTV condition
        uint256 ltvRatio = htlxTrigger.calculateLTV(task.loanId);
        uint256 TARGET_LTV = 12000; // 120%

        if (ltvRatio >= TARGET_LTV) {
            execPayload = abi.encodeWithSelector(
                this.executeTask.selector,
                taskId
            );
            return (true, execPayload);
        }

        return (false, bytes("Condition not met"));
    }

    /**
     * @notice Execute monitoring task
     * @param taskId Task ID
     */
    function executeTask(
        uint256 taskId
    ) external onlyRole(GELATO_ROLE) nonReentrant returns (bool) {
        require(tx.gasprice <= maxGasPrice, "Gas price too high");

        MonitorTask storage task = monitorTasks[taskId];
        require(task.isActive, "Task not active");

        uint256 startGas = gasleft();
        uint256 startTime = block.timestamp;

        // Update collateral and check triggers
        htlxTrigger.updateCollateral(task.loanId);

        task.lastCheck = block.timestamp;
        task.checkCount++;

        uint256 gasUsed = startGas - gasleft();
        uint256 executionTime = block.timestamp - startTime;

        // Update metrics
        ExecutionMetrics storage metrics = taskMetrics[taskId];
        metrics.totalExecutions++;
        metrics.lastExecutionTime = executionTime;

        if (executionTime <= TARGET_SETTLEMENT_TIME) {
            metrics.successfulExecutions++;
        } else {
            metrics.failedExecutions++;
        }

        // Update average
        metrics.averageExecutionTime = (
            (metrics.averageExecutionTime * (metrics.totalExecutions - 1)) +
            executionTime
        ) / metrics.totalExecutions;

        emit ConditionChecked(taskId, task.loanId, true, block.timestamp);

        return true;
    }

    /**
     * @notice Execute trigger directly
     * @param triggerId Trigger ID to execute
     */
    function executeTriggerDirect(
        uint256 triggerId
    ) external onlyRole(GELATO_ROLE) nonReentrant returns (bool) {
        require(tx.gasprice <= maxGasPrice, "Gas price too high");
        require(
            htlxTrigger.canExecuteTrigger(triggerId),
            "Cannot execute trigger"
        );

        uint256 startTime = block.timestamp;
        uint256 startGas = gasleft();

        bool success = htlxTrigger.executeTrigger(triggerId);

        uint256 gasUsed = startGas - gasleft();
        uint256 executionTime = block.timestamp - startTime;

        emit TaskExecuted(triggerId, triggerId, success, executionTime, gasUsed);

        return success;
    }

    /**
     * @notice Deactivate monitoring task
     * @param taskId Task ID
     */
    function deactivateTask(
        uint256 taskId
    ) external onlyRole(OPERATOR_ROLE) {
        MonitorTask storage task = monitorTasks[taskId];
        require(task.isActive, "Task already inactive");

        task.isActive = false;

        emit TaskDeactivated(taskId, task.loanId);
    }

    /**
     * @notice Get task metrics
     */
    function getTaskMetrics(
        uint256 taskId
    ) external view returns (ExecutionMetrics memory) {
        return taskMetrics[taskId];
    }

    /**
     * @notice Update monitoring interval
     */
    function setMonitoringInterval(
        uint256 _interval
    ) external onlyRole(OPERATOR_ROLE) {
        require(_interval >= 1 minutes, "Interval too short");
        monitoringInterval = _interval;
    }

    /**
     * @notice Update max gas price
     */
    function setMaxGasPrice(
        uint256 _maxGasPrice
    ) external onlyRole(OPERATOR_ROLE) {
        require(_maxGasPrice > 0, "Invalid gas price");
        maxGasPrice = _maxGasPrice;
    }

    /**
     * @notice Add Gelato executor
     */
    function addGelatoExecutor(
        address executor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(GELATO_ROLE, executor);
    }

    /**
     * @notice Remove Gelato executor
     */
    function removeGelatoExecutor(
        address executor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(GELATO_ROLE, executor);
    }
}
