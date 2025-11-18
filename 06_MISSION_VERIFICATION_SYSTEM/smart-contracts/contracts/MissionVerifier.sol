// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title MissionVerifier
 * @notice Main contract for DAO-based mission verification system with multi-validator consensus
 * @dev Implements the P5 Mission Verification System Patent Specification
 *
 * Key Features:
 * - Multi-validator consensus (3/3 required)
 * - IPFS evidence storage with on-chain hash
 * - Anti-fraud detection integration
 * - Automated reward distribution
 * - DAO governance for parameters
 *
 * Integration with HTS DAO Ecosystem:
 * - Rewards paid in BLXWT tokens (P2 spec)
 * - Governed by DAO token holders (P3 spec)
 * - Can fund missions from TRR Pools
 */
contract MissionVerifier is AccessControl, ReentrancyGuard, Pausable, VRFConsumerBaseV2 {

    // ============ State Variables ============

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    IERC20 public immutable BLXWT; // Reward token
    VRFCoordinatorV2Interface public immutable vrfCoordinator;

    uint64 public vrfSubscriptionId;
    bytes32 public vrfKeyHash;
    uint32 public vrfCallbackGasLimit = 500000;
    uint16 public vrfRequestConfirmations = 3;
    uint32 public vrfNumWords = 3; // Select 3 validators

    // Mission counter
    uint256 public missionCounter;
    uint256 public submissionCounter;

    // DAO-adjustable parameters
    uint256 public validatorStakeRequirement = 1000 * 10**18; // 1000 BLXWT
    uint256 public fraudScoreThreshold = 75;
    uint256 public validatorFeePercentage = 2; // 2% of reward
    uint256 public maxSubmissionsPerDay = 10;
    uint256 public validationDeadline = 48 hours;
    uint256 public appealBond = 100 * 10**18; // 100 BLXWT

    // ============ Enums ============

    enum MissionState {
        OPEN,           // Accepting submissions
        CLOSED,         // No longer accepting submissions
        COMPLETED,      // Mission completed successfully
        CANCELLED       // Mission cancelled by creator
    }

    enum SubmissionState {
        PENDING,        // Waiting for validators
        VALIDATING,     // Validators assigned, in progress
        APPROVED,       // All validators approved
        REJECTED,       // Rejected by validators or fraud detection
        REWARDED,       // Reward distributed
        APPEALED        // Under appeal review
    }

    enum ValidatorRole {
        EVIDENCE_QUALITY,   // Validator 1: Check evidence quality
        DUPLICATE_CHECK,    // Validator 2: Duplicate detection
        BEHAVIOR_ANALYSIS   // Validator 3: Behavior anomaly
    }

    // ============ Structs ============

    struct Mission {
        address creator;
        string title;
        string criteriaIPFS;        // IPFS CID for detailed criteria
        uint256 rewardAmount;
        uint256 deadline;           // Submission deadline
        MissionState state;
        string category;
        bytes evidenceSchema;       // Expected evidence format
        uint256 createdAt;
        uint256 completedSubmissions;
    }

    struct Submission {
        uint256 missionId;
        address submitter;
        string ipfsCID;             // Evidence stored on IPFS
        bytes32 perceptualHash;     // For duplicate detection
        bytes32 zkProofHash;        // Zero-knowledge proof (optional)
        uint256 timestamp;
        SubmissionState state;
        uint256 validationDeadline;
        uint256 validatorCount;
        uint256 approvalCount;
    }

    struct Validation {
        address validator;
        ValidatorRole role;
        bool hasVoted;
        bool approved;
        string reasonIPFS;          // IPFS CID for detailed reason
        bytes proofHash;            // Cryptographic proof of validation
        uint256 timestamp;
    }

    struct Validator {
        uint256 stakedAmount;
        uint256 reputationScore;
        uint256 totalValidations;
        uint256 correctValidations;
        bool isActive;
        uint256 lastValidationTime;
    }

    struct FraudScore {
        uint256 sybilScore;         // 0-100
        uint256 anomalyScore;       // 0-100
        uint256 duplicateScore;     // 0-100
        uint256 totalScore;         // Weighted average
        bool isFraud;
    }

    // ============ Mappings ============

    mapping(uint256 => Mission) public missions;
    mapping(uint256 => Submission) public submissions;
    mapping(uint256 => mapping(uint256 => Validation)) public validations; // submissionId => validatorIndex => Validation
    mapping(uint256 => address[3]) public assignedValidators; // submissionId => [validator1, validator2, validator3]
    mapping(address => Validator) public validators;
    mapping(address => bool) public blacklist;
    mapping(address => string) public blacklistReason;
    mapping(address => uint256) public blacklistTimestamp;
    mapping(address => mapping(uint256 => uint256)) public dailySubmissions; // user => day => count
    mapping(uint256 => FraudScore) public fraudScores; // submissionId => FraudScore
    mapping(uint256 => uint256) public vrfRequestToSubmission; // VRF requestId => submissionId

    // Reputation NFT tracking
    mapping(address => uint256) public userReputation;
    mapping(address => uint256) public completedMissions;

    // ============ Events ============

    event MissionCreated(
        uint256 indexed missionId,
        address indexed creator,
        uint256 rewardAmount,
        uint256 deadline,
        string category
    );

    event MissionCancelled(uint256 indexed missionId, address indexed creator);

    event SubmissionReceived(
        uint256 indexed submissionId,
        uint256 indexed missionId,
        address indexed submitter,
        string ipfsCID
    );

    event ValidatorsAssigned(
        uint256 indexed submissionId,
        address validator1,
        address validator2,
        address validator3
    );

    event ValidationSubmitted(
        uint256 indexed submissionId,
        address indexed validator,
        ValidatorRole role,
        bool approved
    );

    event ConsensusReached(
        uint256 indexed submissionId,
        bool approved,
        uint256 approvalCount
    );

    event FraudDetected(
        uint256 indexed submissionId,
        address indexed submitter,
        uint256 fraudScore,
        string reason
    );

    event RewardDistributed(
        uint256 indexed submissionId,
        address indexed recipient,
        uint256 amount
    );

    event ValidatorStakeSlashed(
        address indexed validator,
        uint256 amount,
        string reason
    );

    event BlacklistAdded(
        address indexed user,
        uint256 submissionId,
        string reason
    );

    event AppealSubmitted(
        uint256 indexed submissionId,
        address indexed appellant,
        string evidenceCID
    );

    event ParameterChanged(
        string parameter,
        uint256 oldValue,
        uint256 newValue
    );

    // ============ Constructor ============

    constructor(
        address _blxwtToken,
        address _vrfCoordinator,
        uint64 _vrfSubscriptionId,
        bytes32 _vrfKeyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        BLXWT = IERC20(_blxwtToken);
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        vrfSubscriptionId = _vrfSubscriptionId;
        vrfKeyHash = _vrfKeyHash;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DAO_ROLE, msg.sender);
    }

    // ============ Mission Creation Functions ============

    /**
     * @notice Create a new mission with reward locked in escrow
     * @param _title Mission title
     * @param _criteriaIPFS IPFS CID containing detailed success criteria
     * @param _rewardAmount Amount of BLXWT tokens to lock as reward
     * @param _deadline Unix timestamp for submission deadline
     * @param _category Mission category (e.g., "research", "development", "verification")
     * @param _evidenceSchema Expected evidence format specification
     * @return missionId The ID of the created mission
     */
    function createMission(
        string memory _title,
        string memory _criteriaIPFS,
        uint256 _rewardAmount,
        uint256 _deadline,
        string memory _category,
        bytes memory _evidenceSchema
    ) external whenNotPaused nonReentrant returns (uint256 missionId) {
        require(_rewardAmount > 0, "Reward must be positive");
        require(_deadline > block.timestamp, "Deadline must be future");
        require(bytes(_title).length > 0, "Title required");
        require(bytes(_criteriaIPFS).length > 0, "Criteria required");

        // Transfer reward to escrow
        require(
            BLXWT.transferFrom(msg.sender, address(this), _rewardAmount),
            "Reward transfer failed"
        );

        // Create mission
        missionId = ++missionCounter;
        missions[missionId] = Mission({
            creator: msg.sender,
            title: _title,
            criteriaIPFS: _criteriaIPFS,
            rewardAmount: _rewardAmount,
            deadline: _deadline,
            state: MissionState.OPEN,
            category: _category,
            evidenceSchema: _evidenceSchema,
            createdAt: block.timestamp,
            completedSubmissions: 0
        });

        emit MissionCreated(missionId, msg.sender, _rewardAmount, _deadline, _category);
    }

    /**
     * @notice Cancel a mission and return reward to creator
     * @param _missionId Mission ID to cancel
     */
    function cancelMission(uint256 _missionId) external nonReentrant {
        Mission storage mission = missions[_missionId];
        require(msg.sender == mission.creator, "Not mission creator");
        require(mission.state == MissionState.OPEN, "Mission not open");
        require(mission.completedSubmissions == 0, "Mission has completions");

        mission.state = MissionState.CANCELLED;

        // Return reward to creator
        require(
            BLXWT.transfer(mission.creator, mission.rewardAmount),
            "Reward return failed"
        );

        emit MissionCancelled(_missionId, mission.creator);
    }

    // ============ Submission Functions ============

    /**
     * @notice Submit evidence for mission completion
     * @param _missionId Mission ID
     * @param _ipfsCID IPFS Content Identifier for evidence files
     * @param _perceptualHash Perceptual hash for duplicate detection
     * @param _zkProofHash Optional zero-knowledge proof hash
     * @return submissionId The ID of the submission
     */
    function submitEvidence(
        uint256 _missionId,
        string memory _ipfsCID,
        bytes32 _perceptualHash,
        bytes32 _zkProofHash
    ) external whenNotPaused nonReentrant returns (uint256 submissionId) {
        Mission storage mission = missions[_missionId];
        require(mission.state == MissionState.OPEN, "Mission not open");
        require(block.timestamp <= mission.deadline, "Deadline passed");
        require(!blacklist[msg.sender], "Address blacklisted");
        require(bytes(_ipfsCID).length > 0, "IPFS CID required");

        // Check daily submission limit
        uint256 today = block.timestamp / 1 days;
        require(
            dailySubmissions[msg.sender][today] < maxSubmissionsPerDay,
            "Daily submission limit exceeded"
        );
        dailySubmissions[msg.sender][today]++;

        // Create submission
        submissionId = ++submissionCounter;
        submissions[submissionId] = Submission({
            missionId: _missionId,
            submitter: msg.sender,
            ipfsCID: _ipfsCID,
            perceptualHash: _perceptualHash,
            zkProofHash: _zkProofHash,
            timestamp: block.timestamp,
            state: SubmissionState.PENDING,
            validationDeadline: block.timestamp + validationDeadline,
            validatorCount: 0,
            approvalCount: 0
        });

        emit SubmissionReceived(submissionId, _missionId, msg.sender, _ipfsCID);

        // Request validator assignment via Chainlink VRF
        _requestValidatorAssignment(submissionId);
    }

    /**
     * @notice Request validator assignment using Chainlink VRF for randomness
     * @param _submissionId Submission ID
     */
    function _requestValidatorAssignment(uint256 _submissionId) private {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            vrfKeyHash,
            vrfSubscriptionId,
            vrfRequestConfirmations,
            vrfCallbackGasLimit,
            vrfNumWords
        );

        vrfRequestToSubmission[requestId] = _submissionId;
    }

    /**
     * @notice Chainlink VRF callback to assign validators
     * @param requestId VRF request ID
     * @param randomWords Array of random numbers
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 submissionId = vrfRequestToSubmission[requestId];
        require(submissionId > 0, "Invalid VRF request");

        Submission storage submission = submissions[submissionId];
        require(submission.state == SubmissionState.PENDING, "Invalid state");

        // Get list of eligible validators
        address[] memory eligibleValidators = _getEligibleValidators(submission.submitter);
        require(eligibleValidators.length >= 3, "Insufficient validators");

        // Assign 3 validators using VRF randomness
        address[3] memory selected;
        for (uint i = 0; i < 3; i++) {
            uint256 index = randomWords[i] % eligibleValidators.length;
            selected[i] = eligibleValidators[index];

            // Create validation record
            validations[submissionId][i] = Validation({
                validator: selected[i],
                role: ValidatorRole(i), // 0=EVIDENCE_QUALITY, 1=DUPLICATE_CHECK, 2=BEHAVIOR_ANALYSIS
                hasVoted: false,
                approved: false,
                reasonIPFS: "",
                proofHash: bytes(""),
                timestamp: 0
            });

            // Remove selected validator to avoid duplicates
            eligibleValidators[index] = eligibleValidators[eligibleValidators.length - 1];
            // Note: This is a simplified approach; production would use a more efficient algorithm
        }

        assignedValidators[submissionId] = selected;
        submission.state = SubmissionState.VALIDATING;
        submission.validatorCount = 3;

        emit ValidatorsAssigned(submissionId, selected[0], selected[1], selected[2]);
    }

    /**
     * @notice Get list of eligible validators (excluding conflicts of interest)
     * @param _submitter Address of submission creator
     * @return eligible Array of eligible validator addresses
     */
    function _getEligibleValidators(address _submitter) private view returns (address[] memory) {
        // In production, maintain a registry of active validators
        // For now, return a placeholder
        address[] memory eligible = new address[](10);
        // TODO: Implement validator registry and filtering logic
        return eligible;
    }

    // ============ Validation Functions ============

    /**
     * @notice Submit validation decision for a submission
     * @param _submissionId Submission ID
     * @param _validatorIndex Validator index (0, 1, or 2)
     * @param _approved Whether evidence is approved
     * @param _reasonIPFS IPFS CID containing detailed validation reason
     * @param _proofHash Cryptographic proof of validation work
     */
    function submitValidation(
        uint256 _submissionId,
        uint256 _validatorIndex,
        bool _approved,
        string memory _reasonIPFS,
        bytes memory _proofHash
    ) external whenNotPaused nonReentrant {
        require(_validatorIndex < 3, "Invalid validator index");

        Submission storage submission = submissions[_submissionId];
        require(submission.state == SubmissionState.VALIDATING, "Not in validation");
        require(block.timestamp <= submission.validationDeadline, "Validation deadline passed");

        Validation storage validation = validations[_submissionId][_validatorIndex];
        require(validation.validator == msg.sender, "Not assigned validator");
        require(!validation.hasVoted, "Already voted");

        // Record validation
        validation.hasVoted = true;
        validation.approved = _approved;
        validation.reasonIPFS = _reasonIPFS;
        validation.proofHash = _proofHash;
        validation.timestamp = block.timestamp;

        if (_approved) {
            submission.approvalCount++;
        }

        // Update validator stats
        validators[msg.sender].totalValidations++;
        validators[msg.sender].lastValidationTime = block.timestamp;

        emit ValidationSubmitted(_submissionId, msg.sender, validation.role, _approved);

        // Check if all validators have voted
        if (_allValidatorsVoted(_submissionId)) {
            _processConsensus(_submissionId);
        }
    }

    /**
     * @notice Check if all 3 validators have submitted their decisions
     * @param _submissionId Submission ID
     * @return bool True if all voted
     */
    function _allValidatorsVoted(uint256 _submissionId) private view returns (bool) {
        for (uint i = 0; i < 3; i++) {
            if (!validations[_submissionId][i].hasVoted) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Process consensus after all validators have voted
     * @param _submissionId Submission ID
     */
    function _processConsensus(uint256 _submissionId) private {
        Submission storage submission = submissions[_submissionId];

        emit ConsensusReached(_submissionId, submission.approvalCount == 3, submission.approvalCount);

        if (submission.approvalCount == 3) {
            // All 3 validators approved - proceed to anti-fraud detection
            _runAntiFraudChecks(_submissionId);
        } else {
            // At least one validator rejected - reject submission
            submission.state = SubmissionState.REJECTED;
            _returnRewardToCreator(_submissionId);
        }
    }

    /**
     * @notice Run anti-fraud detection checks (placeholder - integrate with FraudDetector contract)
     * @param _submissionId Submission ID
     */
    function _runAntiFraudChecks(uint256 _submissionId) private {
        // TODO: Integrate with FraudDetector contract for:
        // - Sybil detection (wallet graph analysis)
        // - Behavior anomaly detection (statistical scoring)
        // - Duplicate detection (perceptual hash comparison)

        // Placeholder: Assume no fraud detected
        fraudScores[_submissionId] = FraudScore({
            sybilScore: 0,
            anomalyScore: 0,
            duplicateScore: 0,
            totalScore: 0,
            isFraud: false
        });

        if (fraudScores[_submissionId].totalScore >= fraudScoreThreshold) {
            // Fraud detected
            _rejectAndBlacklist(_submissionId, "Fraud detected");
        } else {
            // No fraud - distribute reward
            _distributeReward(_submissionId);
        }
    }

    // ============ Settlement Functions ============

    /**
     * @notice Distribute reward to submitter and validators
     * @param _submissionId Submission ID
     */
    function _distributeReward(uint256 _submissionId) private {
        Submission storage submission = submissions[_submissionId];
        Mission storage mission = missions[submission.missionId];

        require(submission.state != SubmissionState.REWARDED, "Already rewarded");

        // Calculate amounts
        uint256 validatorFeeTotal = (mission.rewardAmount * validatorFeePercentage) / 100;
        uint256 userReward = mission.rewardAmount - validatorFeeTotal;
        uint256 validatorFeeEach = validatorFeeTotal / 3;

        // Transfer reward to submitter
        require(BLXWT.transfer(submission.submitter, userReward), "User reward transfer failed");

        // Transfer fees to validators
        for (uint i = 0; i < 3; i++) {
            address validator = assignedValidators[_submissionId][i];
            require(BLXWT.transfer(validator, validatorFeeEach), "Validator fee transfer failed");

            // Update validator reputation
            validators[validator].reputationScore += 10;
            validators[validator].correctValidations++;
        }

        // Update states
        submission.state = SubmissionState.REWARDED;
        mission.completedSubmissions++;

        // Update user reputation
        userReputation[submission.submitter] += 10;
        completedMissions[submission.submitter]++;

        emit RewardDistributed(_submissionId, submission.submitter, userReward);
    }

    /**
     * @notice Reject submission and blacklist submitter for fraud
     * @param _submissionId Submission ID
     * @param _reason Reason for rejection
     */
    function _rejectAndBlacklist(uint256 _submissionId, string memory _reason) private {
        Submission storage submission = submissions[_submissionId];

        // Blacklist user
        blacklist[submission.submitter] = true;
        blacklistReason[submission.submitter] = _reason;
        blacklistTimestamp[submission.submitter] = block.timestamp;

        submission.state = SubmissionState.REJECTED;

        // Return reward to mission creator
        _returnRewardToCreator(_submissionId);

        emit FraudDetected(_submissionId, submission.submitter, fraudScores[_submissionId].totalScore, _reason);
        emit BlacklistAdded(submission.submitter, _submissionId, _reason);
    }

    /**
     * @notice Return reward to mission creator (on rejection)
     * @param _submissionId Submission ID
     */
    function _returnRewardToCreator(uint256 _submissionId) private {
        Submission storage submission = submissions[_submissionId];
        Mission storage mission = missions[submission.missionId];

        require(BLXWT.transfer(mission.creator, mission.rewardAmount), "Return transfer failed");
    }

    // ============ Validator Management ============

    /**
     * @notice Stake BLXWT to become a validator
     * @param _amount Amount of BLXWT to stake
     */
    function stakeAsValidator(uint256 _amount) external nonReentrant {
        require(_amount >= validatorStakeRequirement, "Insufficient stake");

        require(BLXWT.transferFrom(msg.sender, address(this), _amount), "Stake transfer failed");

        validators[msg.sender].stakedAmount += _amount;
        validators[msg.sender].isActive = true;

        if (validators[msg.sender].reputationScore == 0) {
            validators[msg.sender].reputationScore = 100; // Starting reputation
        }
    }

    /**
     * @notice Unstake BLXWT and deactivate validator status
     */
    function unstake() external nonReentrant {
        Validator storage validator = validators[msg.sender];
        require(validator.stakedAmount > 0, "No stake");

        uint256 amount = validator.stakedAmount;
        validator.stakedAmount = 0;
        validator.isActive = false;

        require(BLXWT.transfer(msg.sender, amount), "Unstake transfer failed");
    }

    /**
     * @notice Slash validator stake for malicious behavior
     * @param _validator Validator address
     * @param _amount Amount to slash
     * @param _reason Reason for slashing
     */
    function slashValidatorStake(
        address _validator,
        uint256 _amount,
        string memory _reason
    ) external onlyRole(DAO_ROLE) {
        Validator storage validator = validators[_validator];
        require(validator.stakedAmount >= _amount, "Insufficient stake to slash");

        validator.stakedAmount -= _amount;
        validator.reputationScore = validator.reputationScore > 50 ? validator.reputationScore - 50 : 0;

        // Slashed funds go to DAO treasury
        // TODO: Implement treasury transfer

        emit ValidatorStakeSlashed(_validator, _amount, _reason);
    }

    // ============ DAO Governance Functions ============

    /**
     * @notice Update validator stake requirement (DAO only)
     * @param _newRequirement New stake requirement
     */
    function setValidatorStakeRequirement(uint256 _newRequirement) external onlyRole(DAO_ROLE) {
        emit ParameterChanged("validatorStakeRequirement", validatorStakeRequirement, _newRequirement);
        validatorStakeRequirement = _newRequirement;
    }

    /**
     * @notice Update fraud score threshold (DAO only)
     * @param _newThreshold New threshold (0-100)
     */
    function setFraudScoreThreshold(uint256 _newThreshold) external onlyRole(DAO_ROLE) {
        require(_newThreshold <= 100, "Invalid threshold");
        emit ParameterChanged("fraudScoreThreshold", fraudScoreThreshold, _newThreshold);
        fraudScoreThreshold = _newThreshold;
    }

    /**
     * @notice Update validator fee percentage (DAO only)
     * @param _newPercentage New percentage (0-100)
     */
    function setValidatorFeePercentage(uint256 _newPercentage) external onlyRole(DAO_ROLE) {
        require(_newPercentage <= 100, "Invalid percentage");
        emit ParameterChanged("validatorFeePercentage", validatorFeePercentage, _newPercentage);
        validatorFeePercentage = _newPercentage;
    }

    // ============ Emergency Functions ============

    /**
     * @notice Pause contract (admin only)
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract (admin only)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get mission details
     * @param _missionId Mission ID
     * @return Mission struct
     */
    function getMission(uint256 _missionId) external view returns (Mission memory) {
        return missions[_missionId];
    }

    /**
     * @notice Get submission details
     * @param _submissionId Submission ID
     * @return Submission struct
     */
    function getSubmission(uint256 _submissionId) external view returns (Submission memory) {
        return submissions[_submissionId];
    }

    /**
     * @notice Get assigned validators for a submission
     * @param _submissionId Submission ID
     * @return Array of 3 validator addresses
     */
    function getAssignedValidators(uint256 _submissionId) external view returns (address[3] memory) {
        return assignedValidators[_submissionId];
    }

    /**
     * @notice Check if address is blacklisted
     * @param _user User address
     * @return bool True if blacklisted
     */
    function isBlacklisted(address _user) external view returns (bool) {
        return blacklist[_user];
    }
}
