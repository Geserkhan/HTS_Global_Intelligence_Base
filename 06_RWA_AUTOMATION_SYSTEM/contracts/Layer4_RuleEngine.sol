// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RuleEngine
 * @notice Layer 4: Compliance Rule Engine
 * @dev Evaluates business rules and compliance checks
 */
contract RuleEngine is AccessControl, ReentrancyGuard {
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant RULE_MANAGER_ROLE = keccak256("RULE_MANAGER_ROLE");

    enum RuleType {
        LTV_CHECK,
        COLLATERAL_QUALITY,
        GEOGRAPHIC_RESTRICTION,
        KYC_AML,
        TRANSACTION_LIMIT,
        TIME_RESTRICTION,
        WHITELIST_CHECK,
        BLACKLIST_CHECK
    }

    enum RuleStatus {
        ACTIVE,
        INACTIVE,
        SUSPENDED
    }

    struct Rule {
        uint256 ruleId;
        RuleType ruleType;
        string name;
        string description;
        RuleStatus status;
        uint256 threshold;
        bytes parameters;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct RuleEvaluation {
        uint256 evaluationId;
        uint256 ruleId;
        address subject;
        bool passed;
        uint256 timestamp;
        bytes result;
        string failureReason;
    }

    struct ComplianceScore {
        address entity;
        uint256 totalEvaluations;
        uint256 passedEvaluations;
        uint256 failedEvaluations;
        uint256 score; // 0-10000 (100%)
        uint256 lastUpdate;
    }

    // Storage
    mapping(uint256 => Rule) public rules;
    mapping(uint256 => RuleEvaluation) public evaluations;
    mapping(address => ComplianceScore) public complianceScores;
    mapping(RuleType => uint256[]) public rulesByType;
    mapping(address => uint256[]) public entityEvaluations;

    uint256 public ruleCount;
    uint256 public evaluationCount;

    // Whitelists and Blacklists
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    mapping(string => bool) public restrictedCountries;

    // Events
    event RuleCreated(
        uint256 indexed ruleId,
        RuleType indexed ruleType,
        string name
    );

    event RuleUpdated(
        uint256 indexed ruleId,
        RuleStatus newStatus
    );

    event RuleEvaluated(
        uint256 indexed evaluationId,
        uint256 indexed ruleId,
        address indexed subject,
        bool passed
    );

    event ComplianceScoreUpdated(
        address indexed entity,
        uint256 newScore,
        uint256 timestamp
    );

    event ComplianceViolation(
        uint256 indexed evaluationId,
        address indexed subject,
        string reason
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RULE_MANAGER_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);

        // Initialize default rules
        _initializeDefaultRules();
    }

    /**
     * @notice Initialize default compliance rules
     */
    function _initializeDefaultRules() internal {
        // LTV Rule
        createRule(
            RuleType.LTV_CHECK,
            "Maximum LTV Ratio",
            "LTV must not exceed 130%",
            13000, // 130%
            ""
        );

        // Transaction Limit
        createRule(
            RuleType.TRANSACTION_LIMIT,
            "Maximum Transaction Amount",
            "Single transaction must not exceed $10M",
            10_000_000 ether,
            ""
        );
    }

    /**
     * @notice Create new rule
     * @param ruleType Type of rule
     * @param name Rule name
     * @param description Rule description
     * @param threshold Threshold value
     * @param parameters Additional parameters
     */
    function createRule(
        RuleType ruleType,
        string memory name,
        string memory description,
        uint256 threshold,
        bytes memory parameters
    ) public onlyRole(RULE_MANAGER_ROLE) returns (uint256) {
        uint256 ruleId = ruleCount++;

        rules[ruleId] = Rule({
            ruleId: ruleId,
            ruleType: ruleType,
            name: name,
            description: description,
            status: RuleStatus.ACTIVE,
            threshold: threshold,
            parameters: parameters,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        rulesByType[ruleType].push(ruleId);

        emit RuleCreated(ruleId, ruleType, name);

        return ruleId;
    }

    /**
     * @notice Evaluate rule
     * @param ruleId Rule ID
     * @param subject Address to evaluate
     * @param value Value to check
     */
    function evaluateRule(
        uint256 ruleId,
        address subject,
        uint256 value
    ) external onlyRole(COMPLIANCE_ROLE) returns (bool) {
        Rule memory rule = rules[ruleId];
        require(rule.status == RuleStatus.ACTIVE, "Rule not active");

        bool passed = false;
        string memory failureReason = "";

        // Evaluate based on rule type
        if (rule.ruleType == RuleType.LTV_CHECK) {
            passed = value <= rule.threshold;
            if (!passed) {
                failureReason = "LTV exceeds maximum threshold";
            }
        } else if (rule.ruleType == RuleType.TRANSACTION_LIMIT) {
            passed = value <= rule.threshold;
            if (!passed) {
                failureReason = "Transaction exceeds maximum limit";
            }
        } else if (rule.ruleType == RuleType.WHITELIST_CHECK) {
            passed = whitelist[subject];
            if (!passed) {
                failureReason = "Address not whitelisted";
            }
        } else if (rule.ruleType == RuleType.BLACKLIST_CHECK) {
            passed = !blacklist[subject];
            if (!passed) {
                failureReason = "Address is blacklisted";
            }
        }

        // Record evaluation
        uint256 evaluationId = evaluationCount++;

        evaluations[evaluationId] = RuleEvaluation({
            evaluationId: evaluationId,
            ruleId: ruleId,
            subject: subject,
            passed: passed,
            timestamp: block.timestamp,
            result: abi.encode(value),
            failureReason: failureReason
        });

        entityEvaluations[subject].push(evaluationId);

        emit RuleEvaluated(evaluationId, ruleId, subject, passed);

        if (!passed) {
            emit ComplianceViolation(evaluationId, subject, failureReason);
        }

        // Update compliance score
        _updateComplianceScore(subject, passed);

        return passed;
    }

    /**
     * @notice Update compliance score
     * @param entity Entity address
     * @param passed Whether evaluation passed
     */
    function _updateComplianceScore(address entity, bool passed) internal {
        ComplianceScore storage score = complianceScores[entity];

        score.entity = entity;
        score.totalEvaluations++;

        if (passed) {
            score.passedEvaluations++;
        } else {
            score.failedEvaluations++;
        }

        // Calculate score (0-10000)
        score.score = (score.passedEvaluations * 10000) / score.totalEvaluations;
        score.lastUpdate = block.timestamp;

        emit ComplianceScoreUpdated(entity, score.score, block.timestamp);
    }

    /**
     * @notice Get compliance score
     * @param entity Entity address
     */
    function getComplianceScore(
        address entity
    ) external view returns (ComplianceScore memory) {
        return complianceScores[entity];
    }

    /**
     * @notice Check if entity is compliant
     * @param entity Entity address
     * @param minimumScore Minimum required score
     */
    function isCompliant(
        address entity,
        uint256 minimumScore
    ) external view returns (bool) {
        ComplianceScore memory score = complianceScores[entity];

        // Check blacklist
        if (blacklist[entity]) {
            return false;
        }

        // Check minimum score
        if (score.totalEvaluations == 0) {
            return true; // No evaluations yet
        }

        return score.score >= minimumScore;
    }

    /**
     * @notice Update rule status
     * @param ruleId Rule ID
     * @param newStatus New status
     */
    function updateRuleStatus(
        uint256 ruleId,
        RuleStatus newStatus
    ) external onlyRole(RULE_MANAGER_ROLE) {
        Rule storage rule = rules[ruleId];
        rule.status = newStatus;
        rule.updatedAt = block.timestamp;

        emit RuleUpdated(ruleId, newStatus);
    }

    /**
     * @notice Add to whitelist
     * @param entity Entity address
     */
    function addToWhitelist(
        address entity
    ) external onlyRole(COMPLIANCE_ROLE) {
        whitelist[entity] = true;
    }

    /**
     * @notice Remove from whitelist
     * @param entity Entity address
     */
    function removeFromWhitelist(
        address entity
    ) external onlyRole(COMPLIANCE_ROLE) {
        whitelist[entity] = false;
    }

    /**
     * @notice Add to blacklist
     * @param entity Entity address
     */
    function addToBlacklist(
        address entity
    ) external onlyRole(COMPLIANCE_ROLE) {
        blacklist[entity] = true;
    }

    /**
     * @notice Remove from blacklist
     * @param entity Entity address
     */
    function removeFromBlacklist(
        address entity
    ) external onlyRole(COMPLIANCE_ROLE) {
        blacklist[entity] = false;
    }

    /**
     * @notice Add restricted country
     * @param countryCode ISO country code
     */
    function addRestrictedCountry(
        string memory countryCode
    ) external onlyRole(COMPLIANCE_ROLE) {
        restrictedCountries[countryCode] = true;
    }

    /**
     * @notice Get entity evaluations
     * @param entity Entity address
     */
    function getEntityEvaluations(
        address entity
    ) external view returns (uint256[] memory) {
        return entityEvaluations[entity];
    }

    /**
     * @notice Get rules by type
     * @param ruleType Rule type
     */
    function getRulesByType(
        RuleType ruleType
    ) external view returns (uint256[] memory) {
        return rulesByType[ruleType];
    }
}
