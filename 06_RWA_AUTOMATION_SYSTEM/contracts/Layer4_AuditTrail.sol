// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AuditTrail
 * @notice Layer 4: Immutable Audit Trail System
 * @dev Records all system events for compliance and verification
 */
contract AuditTrail is AccessControl {
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant SYSTEM_ROLE = keccak256("SYSTEM_ROLE");

    enum EventType {
        PRICE_UPDATE,
        LTV_CALCULATION,
        TRIGGER_ACTIVATION,
        TRIGGER_EXECUTION,
        ORACLE_SUBMISSION,
        CONSENSUS_REACHED,
        RULE_EVALUATION,
        SETTLEMENT_INITIATED,
        SETTLEMENT_COMPLETED,
        SYSTEM_ERROR
    }

    enum Severity {
        INFO,
        WARNING,
        CRITICAL
    }

    struct AuditEntry {
        uint256 entryId;
        EventType eventType;
        Severity severity;
        address actor;
        bytes32 dataHash;
        string description;
        uint256 timestamp;
        uint256 blockNumber;
        bytes metadata;
    }

    struct AuditSummary {
        uint256 totalEntries;
        uint256 infoCount;
        uint256 warningCount;
        uint256 criticalCount;
        uint256 lastEntryTime;
    }

    // Storage
    mapping(uint256 => AuditEntry) public auditLog;
    mapping(EventType => uint256[]) public eventTypeIndex;
    mapping(address => uint256[]) public actorIndex;
    mapping(uint256 => uint256[]) public dailyIndex; // day => entryIds[]

    uint256 public entryCount;
    AuditSummary public summary;

    // Events
    event AuditEntryCreated(
        uint256 indexed entryId,
        EventType indexed eventType,
        Severity severity,
        address indexed actor,
        uint256 timestamp
    );

    event ComplianceAlert(
        uint256 indexed entryId,
        Severity severity,
        string description
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SYSTEM_ROLE, msg.sender);
    }

    /**
     * @notice Record audit entry
     * @param eventType Type of event
     * @param severity Severity level
     * @param description Event description
     * @param metadata Additional metadata
     */
    function recordEntry(
        EventType eventType,
        Severity severity,
        string memory description,
        bytes memory metadata
    ) external onlyRole(SYSTEM_ROLE) returns (uint256) {
        uint256 entryId = entryCount++;

        bytes32 dataHash = keccak256(
            abi.encodePacked(
                entryId,
                eventType,
                msg.sender,
                description,
                block.timestamp
            )
        );

        auditLog[entryId] = AuditEntry({
            entryId: entryId,
            eventType: eventType,
            severity: severity,
            actor: msg.sender,
            dataHash: dataHash,
            description: description,
            timestamp: block.timestamp,
            blockNumber: block.number,
            metadata: metadata
        });

        // Update indexes
        eventTypeIndex[eventType].push(entryId);
        actorIndex[msg.sender].push(entryId);

        uint256 day = block.timestamp / 1 days;
        dailyIndex[day].push(entryId);

        // Update summary
        summary.totalEntries++;
        summary.lastEntryTime = block.timestamp;

        if (severity == Severity.INFO) {
            summary.infoCount++;
        } else if (severity == Severity.WARNING) {
            summary.warningCount++;
        } else if (severity == Severity.CRITICAL) {
            summary.criticalCount++;
        }

        emit AuditEntryCreated(
            entryId,
            eventType,
            severity,
            msg.sender,
            block.timestamp
        );

        if (severity == Severity.CRITICAL) {
            emit ComplianceAlert(entryId, severity, description);
        }

        return entryId;
    }

    /**
     * @notice Get entries by event type
     * @param eventType Event type
     */
    function getEntriesByEventType(
        EventType eventType
    ) external view returns (uint256[] memory) {
        return eventTypeIndex[eventType];
    }

    /**
     * @notice Get entries by actor
     * @param actor Actor address
     */
    function getEntriesByActor(
        address actor
    ) external view returns (uint256[] memory) {
        return actorIndex[actor];
    }

    /**
     * @notice Get entries for a specific day
     * @param day Day timestamp (in days since epoch)
     */
    function getDailyEntries(
        uint256 day
    ) external view returns (uint256[] memory) {
        return dailyIndex[day];
    }

    /**
     * @notice Get audit entry details
     * @param entryId Entry ID
     */
    function getEntry(
        uint256 entryId
    ) external view returns (AuditEntry memory) {
        return auditLog[entryId];
    }

    /**
     * @notice Verify audit entry integrity
     * @param entryId Entry ID
     */
    function verifyEntry(uint256 entryId) external view returns (bool) {
        AuditEntry memory entry = auditLog[entryId];

        bytes32 computedHash = keccak256(
            abi.encodePacked(
                entry.entryId,
                entry.eventType,
                entry.actor,
                entry.description,
                entry.timestamp
            )
        );

        return computedHash == entry.dataHash;
    }

    /**
     * @notice Get summary statistics
     */
    function getSummary() external view returns (AuditSummary memory) {
        return summary;
    }

    /**
     * @notice Add system role
     */
    function addSystemRole(
        address system
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(SYSTEM_ROLE, system);
    }

    /**
     * @notice Remove system role
     */
    function removeSystemRole(
        address system
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(SYSTEM_ROLE, system);
    }
}
