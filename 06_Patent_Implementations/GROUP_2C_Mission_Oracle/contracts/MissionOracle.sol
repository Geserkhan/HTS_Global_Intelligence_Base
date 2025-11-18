// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MissionOracle
 * @notice Verifies and validates mission completion for incentive distribution
 * @dev Implements fraud detection and multi-party verification
 */
contract MissionOracle {

    struct Mission {
        uint256 missionId;
        address creator;
        string missionType;        // "trade", "stake", "provide_liquidity", etc.
        bytes32 requirementsHash;  // Hash of mission requirements
        uint256 rewardAmount;
        uint256 deadline;
        MissionStatus status;
        uint256 participantCount;
        uint256 completedCount;
    }

    struct MissionSubmission {
        uint256 submissionId;
        uint256 missionId;
        address participant;
        bytes proofData;
        uint256 submittedAt;
        SubmissionStatus status;
        uint256 verificationCount;
        uint256 approvalCount;
    }

    struct Verifier {
        address verifierAddress;
        uint256 stake;
        uint256 verificationsCompleted;
        uint256 reputationScore;
        bool isActive;
    }

    enum MissionStatus { Active, Paused, Completed, Cancelled }
    enum SubmissionStatus { Pending, Verified, Rejected, Disputed }

    mapping(uint256 => Mission) public missions;
    mapping(uint256 => MissionSubmission) public submissions;
    mapping(address => Verifier) public verifiers;
    mapping(uint256 => mapping(address => bool)) public hasVerified;

    uint256 public missionCounter;
    uint256 public submissionCounter;
    uint256 public constant MIN_VERIFIERS = 3;
    uint256 public constant MIN_VERIFIER_STAKE = 100 ether;

    event MissionCreated(uint256 indexed missionId, address creator, uint256 reward);
    event MissionSubmitted(uint256 indexed submissionId, uint256 missionId, address participant);
    event SubmissionVerified(uint256 indexed submissionId, address verifier, bool approved);
    event RewardDistributed(uint256 indexed missionId, address participant, uint256 amount);

    function createMission(
        string calldata missionType,
        bytes32 requirementsHash,
        uint256 deadline
    ) external payable returns (uint256 missionId) {
        require(msg.value > 0, "Reward required");
        require(deadline > block.timestamp, "Invalid deadline");

        missionId = ++missionCounter;
        missions[missionId] = Mission({
            missionId: missionId,
            creator: msg.sender,
            missionType: missionType,
            requirementsHash: requirementsHash,
            rewardAmount: msg.value,
            deadline: deadline,
            status: MissionStatus.Active,
            participantCount: 0,
            completedCount: 0
        });

        emit MissionCreated(missionId, msg.sender, msg.value);
    }

    function submitCompletion(
        uint256 missionId,
        bytes calldata proofData
    ) external returns (uint256 submissionId) {
        Mission storage mission = missions[missionId];
        require(mission.status == MissionStatus.Active, "Mission not active");
        require(block.timestamp <= mission.deadline, "Deadline passed");

        submissionId = ++submissionCounter;
        submissions[submissionId] = MissionSubmission({
            submissionId: submissionId,
            missionId: missionId,
            participant: msg.sender,
            proofData: proofData,
            submittedAt: block.timestamp,
            status: SubmissionStatus.Pending,
            verificationCount: 0,
            approvalCount: 0
        });

        mission.participantCount++;
        emit MissionSubmitted(submissionId, missionId, msg.sender);
    }

    function verifySubmission(
        uint256 submissionId,
        bool approve
    ) external {
        require(verifiers[msg.sender].isActive, "Not a verifier");
        require(!hasVerified[submissionId][msg.sender], "Already verified");

        MissionSubmission storage submission = submissions[submissionId];
        require(submission.status == SubmissionStatus.Pending, "Not pending");

        hasVerified[submissionId][msg.sender] = true;
        submission.verificationCount++;

        if (approve) {
            submission.approvalCount++;
        }

        verifiers[msg.sender].verificationsCompleted++;

        // If majority approved, mark as verified
        if (submission.approvalCount >= MIN_VERIFIERS) {
            submission.status = SubmissionStatus.Verified;
            _distributeReward(submissionId);
        } else if (submission.verificationCount - submission.approvalCount >= MIN_VERIFIERS) {
            submission.status = SubmissionStatus.Rejected;
        }

        emit SubmissionVerified(submissionId, msg.sender, approve);
    }

    function _distributeReward(uint256 submissionId) internal {
        MissionSubmission memory submission = submissions[submissionId];
        Mission storage mission = missions[submission.missionId];

        uint256 reward = mission.rewardAmount / (mission.participantCount > 0 ? mission.participantCount : 1);

        payable(submission.participant).transfer(reward);
        mission.completedCount++;

        emit RewardDistributed(submission.missionId, submission.participant, reward);
    }

    function registerVerifier() external payable {
        require(msg.value >= MIN_VERIFIER_STAKE, "Insufficient stake");
        require(!verifiers[msg.sender].isActive, "Already registered");

        verifiers[msg.sender] = Verifier({
            verifierAddress: msg.sender,
            stake: msg.value,
            verificationsCompleted: 0,
            reputationScore: 50,
            isActive: true
        });
    }
}
