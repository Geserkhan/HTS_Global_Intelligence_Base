// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ProofOfTrust
 * @notice Layer 4: Proof of Trust with 7-Oracle Consensus System
 * @dev Multi-oracle consensus mechanism for trust verification
 */
contract ProofOfTrust is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    uint256 public constant REQUIRED_ORACLES = 7;
    uint256 public constant CONSENSUS_THRESHOLD = 5; // 5 out of 7

    struct OracleSubmission {
        address oracle;
        uint256 basketValue;
        uint256 timestamp;
        bytes32 dataHash;
        bool isValid;
    }

    struct ConsensusRound {
        uint256 roundId;
        uint256 timestamp;
        uint256 submissionCount;
        uint256 consensusValue;
        bool isFinalized;
        mapping(address => OracleSubmission) submissions;
        address[] submittedOracles;
    }

    struct TrustMetrics {
        uint256 totalSubmissions;
        uint256 consensusMatches;
        uint256 deviations;
        uint256 trustScore; // 0-10000 (100%)
        uint256 lastUpdate;
    }

    // Storage
    mapping(uint256 => ConsensusRound) public consensusRounds;
    mapping(address => TrustMetrics) public oracleMetrics;
    mapping(address => bool) public activeOracles;

    address[] public registeredOracles;
    uint256 public roundCount;
    uint256 public activeOracleCount;

    // Configuration
    uint256 public maxDeviation = 500; // 5% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public roundDuration = 5 minutes;

    // Events
    event OracleRegistered(address indexed oracle, uint256 timestamp);
    event OracleDeactivated(address indexed oracle, uint256 timestamp);
    event SubmissionReceived(
        uint256 indexed roundId,
        address indexed oracle,
        uint256 value,
        bytes32 dataHash
    );
    event ConsensusReached(
        uint256 indexed roundId,
        uint256 consensusValue,
        uint256 submissionCount
    );
    event TrustScoreUpdated(
        address indexed oracle,
        uint256 newScore,
        uint256 timestamp
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Register new oracle
     * @param oracle Oracle address
     */
    function registerOracle(
        address oracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(oracle != address(0), "Invalid oracle address");
        require(!activeOracles[oracle], "Oracle already registered");
        require(
            activeOracleCount < REQUIRED_ORACLES,
            "Maximum oracles reached"
        );

        grantRole(ORACLE_ROLE, oracle);
        activeOracles[oracle] = true;
        registeredOracles.push(oracle);
        activeOracleCount++;

        oracleMetrics[oracle] = TrustMetrics({
            totalSubmissions: 0,
            consensusMatches: 0,
            deviations: 0,
            trustScore: 10000, // Start with perfect score
            lastUpdate: block.timestamp
        });

        emit OracleRegistered(oracle, block.timestamp);
    }

    /**
     * @notice Submit oracle data
     * @param basketValue Reported basket value
     * @param dataHash Hash of supporting data
     */
    function submitOracleData(
        uint256 basketValue,
        bytes32 dataHash
    ) external onlyRole(ORACLE_ROLE) nonReentrant {
        require(activeOracles[msg.sender], "Oracle not active");
        require(basketValue > 0, "Invalid basket value");

        // Get or create current round
        uint256 currentRound = _getCurrentRound();
        ConsensusRound storage round = consensusRounds[currentRound];

        require(
            round.submissions[msg.sender].timestamp == 0,
            "Already submitted for this round"
        );

        // Store submission
        round.submissions[msg.sender] = OracleSubmission({
            oracle: msg.sender,
            basketValue: basketValue,
            timestamp: block.timestamp,
            dataHash: dataHash,
            isValid: true
        });

        round.submittedOracles.push(msg.sender);
        round.submissionCount++;

        // Update oracle metrics
        TrustMetrics storage metrics = oracleMetrics[msg.sender];
        metrics.totalSubmissions++;
        metrics.lastUpdate = block.timestamp;

        emit SubmissionReceived(currentRound, msg.sender, basketValue, dataHash);

        // Check if consensus can be reached
        if (round.submissionCount >= CONSENSUS_THRESHOLD) {
            _calculateConsensus(currentRound);
        }
    }

    /**
     * @notice Calculate consensus from submissions
     * @param roundId Round ID
     */
    function _calculateConsensus(uint256 roundId) internal {
        ConsensusRound storage round = consensusRounds[roundId];
        require(!round.isFinalized, "Round already finalized");
        require(
            round.submissionCount >= CONSENSUS_THRESHOLD,
            "Not enough submissions"
        );

        // Collect all values
        uint256[] memory values = new uint256[](round.submissionCount);
        for (uint256 i = 0; i < round.submittedOracles.length; i++) {
            address oracle = round.submittedOracles[i];
            values[i] = round.submissions[oracle].basketValue;
        }

        // Calculate median value
        uint256 consensusValue = _calculateMedian(values);

        // Update round
        round.consensusValue = consensusValue;
        round.isFinalized = true;

        // Update trust scores
        _updateTrustScores(roundId, consensusValue);

        emit ConsensusReached(roundId, consensusValue, round.submissionCount);
    }

    /**
     * @notice Calculate median value
     * @param values Array of values
     */
    function _calculateMedian(
        uint256[] memory values
    ) internal pure returns (uint256) {
        // Sort values (bubble sort for simplicity)
        for (uint256 i = 0; i < values.length; i++) {
            for (uint256 j = i + 1; j < values.length; j++) {
                if (values[i] > values[j]) {
                    uint256 temp = values[i];
                    values[i] = values[j];
                    values[j] = temp;
                }
            }
        }

        // Return median
        uint256 mid = values.length / 2;
        if (values.length % 2 == 0) {
            return (values[mid - 1] + values[mid]) / 2;
        } else {
            return values[mid];
        }
    }

    /**
     * @notice Update trust scores based on consensus
     * @param roundId Round ID
     * @param consensusValue Consensus value
     */
    function _updateTrustScores(
        uint256 roundId,
        uint256 consensusValue
    ) internal {
        ConsensusRound storage round = consensusRounds[roundId];

        for (uint256 i = 0; i < round.submittedOracles.length; i++) {
            address oracle = round.submittedOracles[i];
            OracleSubmission memory submission = round.submissions[oracle];
            TrustMetrics storage metrics = oracleMetrics[oracle];

            // Calculate deviation
            uint256 deviation = _calculateDeviation(
                consensusValue,
                submission.basketValue
            );

            if (deviation <= maxDeviation) {
                // Within acceptable range - increase trust
                metrics.consensusMatches++;
                if (metrics.trustScore < 10000) {
                    metrics.trustScore += 100; // +1%
                    if (metrics.trustScore > 10000) {
                        metrics.trustScore = 10000;
                    }
                }
            } else {
                // Outside acceptable range - decrease trust
                metrics.deviations++;
                if (metrics.trustScore >= 200) {
                    metrics.trustScore -= 200; // -2%
                } else {
                    metrics.trustScore = 0;
                }
            }

            emit TrustScoreUpdated(oracle, metrics.trustScore, block.timestamp);
        }
    }

    /**
     * @notice Calculate deviation between values
     */
    function _calculateDeviation(
        uint256 value1,
        uint256 value2
    ) internal pure returns (uint256) {
        if (value1 >= value2) {
            return ((value1 - value2) * BASIS_POINTS) / value1;
        } else {
            return ((value2 - value1) * BASIS_POINTS) / value2;
        }
    }

    /**
     * @notice Get current round ID
     */
    function _getCurrentRound() internal returns (uint256) {
        if (roundCount == 0) {
            consensusRounds[0].roundId = 0;
            consensusRounds[0].timestamp = block.timestamp;
            return 0;
        }

        ConsensusRound storage lastRound = consensusRounds[roundCount - 1];

        if (
            block.timestamp >= lastRound.timestamp + roundDuration ||
            lastRound.isFinalized
        ) {
            // Start new round
            consensusRounds[roundCount].roundId = roundCount;
            consensusRounds[roundCount].timestamp = block.timestamp;
            roundCount++;
            return roundCount - 1;
        }

        return roundCount - 1;
    }

    /**
     * @notice Get consensus value for round
     * @param roundId Round ID
     */
    function getConsensusValue(
        uint256 roundId
    ) external view returns (uint256, bool) {
        ConsensusRound storage round = consensusRounds[roundId];
        return (round.consensusValue, round.isFinalized);
    }

    /**
     * @notice Get oracle trust score
     * @param oracle Oracle address
     */
    function getTrustScore(address oracle) external view returns (uint256) {
        return oracleMetrics[oracle].trustScore;
    }

    /**
     * @notice Get round submissions
     * @param roundId Round ID
     */
    function getRoundSubmissions(
        uint256 roundId
    ) external view returns (address[] memory) {
        return consensusRounds[roundId].submittedOracles;
    }

    /**
     * @notice Deactivate oracle
     * @param oracle Oracle address
     */
    function deactivateOracle(
        address oracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(activeOracles[oracle], "Oracle not active");

        activeOracles[oracle] = false;
        activeOracleCount--;
        revokeRole(ORACLE_ROLE, oracle);

        emit OracleDeactivated(oracle, block.timestamp);
    }

    /**
     * @notice Update max deviation
     */
    function setMaxDeviation(
        uint256 _maxDeviation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxDeviation <= 2000, "Deviation too high"); // Max 20%
        maxDeviation = _maxDeviation;
    }

    /**
     * @notice Update round duration
     */
    function setRoundDuration(
        uint256 _duration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_duration >= 1 minutes, "Duration too short");
        roundDuration = _duration;
    }
}
