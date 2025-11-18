// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * @title FraudDetector
 * @notice Anti-fraud detection module for mission verification system
 * @dev Implements three-layer fraud detection:
 *      1. Sybil Detection - Wallet graph analysis
 *      2. Behavior Anomaly - Statistical deviation scoring
 *      3. Duplicate Detection - Perceptual hash comparison
 *
 * Integrates with Chainlink Functions for off-chain computation
 */
contract FraudDetector is AccessControl, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    // ============ Constants ============

    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Fraud score weights (must sum to 100)
    uint256 public constant SYBIL_WEIGHT = 50;
    uint256 public constant ANOMALY_WEIGHT = 30;
    uint256 public constant DUPLICATE_WEIGHT = 20;

    // ============ State Variables ============

    // Sybil detection parameters
    uint256 public sybilScoreThreshold = 70; // High risk if > 70
    uint256 public commonFundingWeight = 40;
    uint256 public transactionPatternWeight = 30;
    uint256 public deviceFingerprintWeight = 20;
    uint256 public networkGraphWeight = 10;

    // Behavior anomaly parameters
    uint256 public anomalyZScoreThreshold = 300; // 3.0 in fixed-point (x100)
    uint256 public populationMean = 5; // Average submissions per user
    uint256 public populationStdDev = 2; // Standard deviation

    // Duplicate detection parameters
    uint256 public duplicateHammingThreshold = 5; // Max bits difference
    uint256 public duplicateJaccardThreshold = 95; // Min similarity % for text

    // Chainlink oracle configuration
    bytes32 public externalAdapterId;
    uint256 public oracleFee;

    // ============ Structs ============

    struct SybilScore {
        uint256 commonFundingScore;
        uint256 transactionPatternScore;
        uint256 deviceFingerprintScore;
        uint256 networkGraphScore;
        uint256 totalScore;
    }

    struct BehaviorScore {
        uint256 submissionFrequency;
        uint256 accountAge;
        uint256 successRate;
        uint256 timePattern;
        uint256 zScore;
    }

    struct DuplicateMatch {
        bool isDuplicate;
        uint256 originalSubmissionId;
        uint256 hammingDistance;
        uint256 jaccardSimilarity;
    }

    struct FraudAnalysis {
        SybilScore sybil;
        BehaviorScore behavior;
        DuplicateMatch duplicate;
        uint256 aggregateScore;
        bool isFraud;
        string reason;
    }

    // ============ Mappings ============

    mapping(uint256 => FraudAnalysis) public fraudAnalyses; // submissionId => FraudAnalysis
    mapping(bytes32 => uint256[]) public perceptualHashRegistry; // hash => submissionIds
    mapping(address => address[]) public walletGraph; // user => connected wallets
    mapping(address => uint256) public accountCreationTime;
    mapping(address => uint256) public totalSubmissions;
    mapping(address => uint256) public approvedSubmissions;
    mapping(bytes32 => uint256) public pendingRequests; // Chainlink requestId => submissionId

    // ============ Events ============

    event SybilScoreCalculated(
        uint256 indexed submissionId,
        address indexed user,
        uint256 score
    );

    event BehaviorAnomalyDetected(
        uint256 indexed submissionId,
        address indexed user,
        uint256 zScore
    );

    event DuplicateFound(
        uint256 indexed submissionId,
        uint256 originalSubmissionId,
        uint256 similarity
    );

    event FraudAnalysisComplete(
        uint256 indexed submissionId,
        uint256 aggregateScore,
        bool isFraud
    );

    event OracleRequestSent(
        bytes32 indexed requestId,
        uint256 submissionId
    );

    // ============ Constructor ============

    constructor(
        address _linkToken,
        address _oracle
    ) {
        setChainlinkToken(_linkToken);
        setChainlinkOracle(_oracle);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ============ Main Fraud Detection Function ============

    /**
     * @notice Run comprehensive fraud detection on a submission
     * @param _submissionId Submission ID
     * @param _submitter User address
     * @param _perceptualHash Evidence perceptual hash
     * @param _timestamp Submission timestamp
     * @return aggregateScore Overall fraud score (0-100)
     * @return isFraud Whether fraud was detected
     */
    function detectFraud(
        uint256 _submissionId,
        address _submitter,
        bytes32 _perceptualHash,
        uint256 _timestamp
    ) external onlyRole(VERIFIER_ROLE) returns (uint256 aggregateScore, bool isFraud) {
        // 1. Sybil Detection
        SybilScore memory sybilScore = _calculateSybilScore(_submitter);

        // 2. Behavior Anomaly Detection
        BehaviorScore memory behaviorScore = _calculateBehaviorScore(_submitter, _timestamp);

        // 3. Duplicate Detection
        DuplicateMatch memory duplicateMatch = _checkDuplicate(_perceptualHash, _submissionId);

        // Calculate aggregate fraud score
        aggregateScore = _calculateAggregateScore(
            sybilScore.totalScore,
            behaviorScore.zScore,
            duplicateMatch.isDuplicate ? 100 : 0
        );

        isFraud = aggregateScore >= 75; // Threshold from P5 spec

        // Store analysis
        fraudAnalyses[_submissionId] = FraudAnalysis({
            sybil: sybilScore,
            behavior: behaviorScore,
            duplicate: duplicateMatch,
            aggregateScore: aggregateScore,
            isFraud: isFraud,
            reason: _generateReason(sybilScore, behaviorScore, duplicateMatch)
        });

        // Register hash for future duplicate detection
        perceptualHashRegistry[_perceptualHash].push(_submissionId);

        emit FraudAnalysisComplete(_submissionId, aggregateScore, isFraud);
    }

    // ============ Sybil Detection ============

    /**
     * @notice Calculate Sybil attack score via wallet graph analysis
     * @param _user User address
     * @return SybilScore struct with breakdown
     */
    function _calculateSybilScore(address _user) private view returns (SybilScore memory) {
        uint256 commonFundingScore = _analyzeCommonFunding(_user);
        uint256 transactionPatternScore = _analyzeTransactionPatterns(_user);
        uint256 deviceFingerprintScore = _analyzeDeviceFingerprint(_user);
        uint256 networkGraphScore = _analyzeNetworkGraph(_user);

        uint256 totalScore = (
            (commonFundingScore * commonFundingWeight) +
            (transactionPatternScore * transactionPatternWeight) +
            (deviceFingerprintScore * deviceFingerprintWeight) +
            (networkGraphScore * networkGraphWeight)
        ) / 100;

        return SybilScore({
            commonFundingScore: commonFundingScore,
            transactionPatternScore: transactionPatternScore,
            deviceFingerprintScore: deviceFingerprintScore,
            networkGraphScore: networkGraphScore,
            totalScore: totalScore
        });
    }

    /**
     * @notice Analyze if multiple wallets share common funding source
     * @param _user User address
     * @return score 0-100 based on connected wallets
     */
    function _analyzeCommonFunding(address _user) private view returns (uint256) {
        address[] memory connectedWallets = walletGraph[_user];

        if (connectedWallets.length == 0) return 0;
        if (connectedWallets.length >= 5) return 100; // 5+ connected = max score

        // Linear scaling: 0 wallets = 0, 5 wallets = 100
        return (connectedWallets.length * 100) / 5;
    }

    /**
     * @notice Analyze transaction patterns for similarity (gas price, timing)
     * @param _user User address
     * @return score 0-100 based on pattern similarity
     */
    function _analyzeTransactionPatterns(address _user) private view returns (uint256) {
        // Placeholder: In production, analyze:
        // - Gas price patterns (identical gas prices = suspicious)
        // - Transaction timing (regular intervals = bot behavior)
        // - Nonce patterns
        // This requires indexing historical transactions off-chain

        // For now, return 0 (no pattern detected)
        return 0;
    }

    /**
     * @notice Analyze device fingerprint (requires off-chain data)
     * @param _user User address
     * @return score 0-100 based on fingerprint matches
     */
    function _analyzeDeviceFingerprint(address _user) private pure returns (uint256) {
        // Placeholder: In production, integrate with off-chain service
        // - Browser fingerprint (Canvas, WebGL hash)
        // - IP address analysis (Tor/VPN detection)
        // - Device characteristics

        // For now, return 0 (no fingerprint data)
        return 0;
    }

    /**
     * @notice Analyze wallet position in transaction graph
     * @param _user User address
     * @return score 0-100 based on centrality metrics
     */
    function _analyzeNetworkGraph(address _user) private view returns (uint256) {
        // Placeholder: Calculate graph centrality
        // - Betweenness centrality (broker role in graph)
        // - Closeness centrality (distance to other nodes)
        // This requires graph database off-chain

        // For now, simple degree centrality
        uint256 degree = walletGraph[_user].length;
        if (degree >= 10) return 100;
        return (degree * 100) / 10;
    }

    /**
     * @notice Register wallet connection for Sybil detection
     * @param _user1 First wallet address
     * @param _user2 Second wallet address
     */
    function registerWalletConnection(
        address _user1,
        address _user2
    ) external onlyRole(ADMIN_ROLE) {
        // Add bidirectional connection
        walletGraph[_user1].push(_user2);
        walletGraph[_user2].push(_user1);
    }

    // ============ Behavior Anomaly Detection ============

    /**
     * @notice Calculate behavior anomaly score using Z-score
     * @param _user User address
     * @param _timestamp Submission timestamp
     * @return BehaviorScore struct with Z-score
     */
    function _calculateBehaviorScore(
        address _user,
        uint256 _timestamp
    ) private view returns (BehaviorScore memory) {
        // Calculate submission frequency (submissions per day)
        uint256 accountAge = block.timestamp - accountCreationTime[_user];
        uint256 daysOld = accountAge / 1 days;
        daysOld = daysOld == 0 ? 1 : daysOld; // Avoid division by zero

        uint256 submissionFrequency = totalSubmissions[_user] / daysOld;

        // Calculate success rate
        uint256 successRate = totalSubmissions[_user] > 0
            ? (approvedSubmissions[_user] * 100) / totalSubmissions[_user]
            : 0;

        // Calculate Z-score for submission frequency
        uint256 zScore = _calculateZScore(submissionFrequency, populationMean, populationStdDev);

        return BehaviorScore({
            submissionFrequency: submissionFrequency,
            accountAge: daysOld,
            successRate: successRate,
            timePattern: 0, // Placeholder
            zScore: zScore
        });
    }

    /**
     * @notice Calculate Z-score (standard deviations from mean)
     * @param _value Observed value
     * @param _mean Population mean
     * @param _stdDev Population standard deviation
     * @return zScore Absolute Z-score × 100 (e.g., 3.0 = 300)
     */
    function _calculateZScore(
        uint256 _value,
        uint256 _mean,
        uint256 _stdDev
    ) private pure returns (uint256) {
        if (_stdDev == 0) return 0;

        uint256 deviation = _value > _mean ? _value - _mean : _mean - _value;
        return (deviation * 100) / _stdDev; // Fixed-point: multiply by 100
    }

    /**
     * @notice Update user submission statistics
     * @param _user User address
     * @param _approved Whether submission was approved
     */
    function updateUserStats(
        address _user,
        bool _approved
    ) external onlyRole(VERIFIER_ROLE) {
        totalSubmissions[_user]++;
        if (_approved) {
            approvedSubmissions[_user]++;
        }

        // Set account creation time if first submission
        if (accountCreationTime[_user] == 0) {
            accountCreationTime[_user] = block.timestamp;
        }
    }

    // ============ Duplicate Detection ============

    /**
     * @notice Check for duplicate evidence using perceptual hash
     * @param _hash Perceptual hash of new evidence
     * @param _currentSubmissionId Current submission ID
     * @return DuplicateMatch struct with match details
     */
    function _checkDuplicate(
        bytes32 _hash,
        uint256 _currentSubmissionId
    ) private view returns (DuplicateMatch memory) {
        uint256[] memory historicalSubmissions = perceptualHashRegistry[_hash];

        // Check exact hash match
        if (historicalSubmissions.length > 0) {
            return DuplicateMatch({
                isDuplicate: true,
                originalSubmissionId: historicalSubmissions[0],
                hammingDistance: 0,
                jaccardSimilarity: 100
            });
        }

        // Check similar hashes (Hamming distance)
        // Note: This is gas-intensive; in production, use off-chain indexing
        // For now, return no duplicate
        return DuplicateMatch({
            isDuplicate: false,
            originalSubmissionId: 0,
            hammingDistance: type(uint256).max,
            jaccardSimilarity: 0
        });
    }

    /**
     * @notice Calculate Hamming distance between two hashes
     * @param _hash1 First hash
     * @param _hash2 Second hash
     * @return distance Number of differing bits
     */
    function calculateHammingDistance(
        bytes32 _hash1,
        bytes32 _hash2
    ) public pure returns (uint256 distance) {
        bytes32 xor = _hash1 ^ _hash2;

        // Count set bits in XOR result
        for (uint i = 0; i < 256; i++) {
            if ((uint256(xor) >> i) & 1 == 1) {
                distance++;
            }
        }
    }

    // ============ Aggregate Scoring ============

    /**
     * @notice Calculate weighted aggregate fraud score
     * @param _sybilScore Sybil detection score (0-100)
     * @param _anomalyZScore Behavior Z-score (× 100)
     * @param _duplicateScore Duplicate detection score (0 or 100)
     * @return aggregateScore Weighted fraud score (0-100)
     */
    function _calculateAggregateScore(
        uint256 _sybilScore,
        uint256 _anomalyZScore,
        uint256 _duplicateScore
    ) private pure returns (uint256) {
        // Convert Z-score to 0-100 scale (cap at 100)
        uint256 anomalyScore = _anomalyZScore >= 300 ? 100 : (_anomalyZScore * 100) / 300;

        // Weighted average
        uint256 aggregateScore = (
            (_sybilScore * SYBIL_WEIGHT) +
            (anomalyScore * ANOMALY_WEIGHT) +
            (_duplicateScore * DUPLICATE_WEIGHT)
        ) / 100;

        return aggregateScore > 100 ? 100 : aggregateScore;
    }

    /**
     * @notice Generate human-readable fraud reason
     * @param _sybil SybilScore struct
     * @param _behavior BehaviorScore struct
     * @param _duplicate DuplicateMatch struct
     * @return reason Fraud explanation
     */
    function _generateReason(
        SybilScore memory _sybil,
        BehaviorScore memory _behavior,
        DuplicateMatch memory _duplicate
    ) private pure returns (string memory) {
        if (_duplicate.isDuplicate) {
            return "Duplicate evidence detected";
        }
        if (_sybil.totalScore >= 70) {
            return "Sybil attack detected (multiple connected wallets)";
        }
        if (_behavior.zScore >= 300) {
            return "Behavior anomaly detected (statistical outlier)";
        }
        return "No fraud detected";
    }

    // ============ Chainlink Integration ============

    /**
     * @notice Request off-chain fraud analysis via Chainlink Functions
     * @param _submissionId Submission ID
     * @param _user User address
     * @param _evidenceCID IPFS CID for evidence
     * @return requestId Chainlink request ID
     */
    function requestOffchainAnalysis(
        uint256 _submissionId,
        address _user,
        string memory _evidenceCID
    ) external onlyRole(VERIFIER_ROLE) returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            externalAdapterId,
            address(this),
            this.fulfillOffchainAnalysis.selector
        );

        // Add parameters
        req.add("submissionId", uint2str(_submissionId));
        req.add("user", toAsciiString(_user));
        req.add("evidenceCID", _evidenceCID);

        requestId = sendChainlinkRequest(req, oracleFee);
        pendingRequests[requestId] = _submissionId;

        emit OracleRequestSent(requestId, _submissionId);
    }

    /**
     * @notice Chainlink callback for off-chain analysis results
     * @param _requestId Chainlink request ID
     * @param _fraudScore Fraud score from off-chain analysis
     */
    function fulfillOffchainAnalysis(
        bytes32 _requestId,
        uint256 _fraudScore
    ) public recordChainlinkFulfillment(_requestId) {
        uint256 submissionId = pendingRequests[_requestId];
        require(submissionId > 0, "Invalid request ID");

        // Update fraud analysis with off-chain result
        fraudAnalyses[submissionId].aggregateScore = _fraudScore;
        fraudAnalyses[submissionId].isFraud = _fraudScore >= 75;

        emit FraudAnalysisComplete(submissionId, _fraudScore, _fraudScore >= 75);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update Sybil detection threshold
     * @param _newThreshold New threshold (0-100)
     */
    function setSybilScoreThreshold(uint256 _newThreshold) external onlyRole(ADMIN_ROLE) {
        require(_newThreshold <= 100, "Invalid threshold");
        sybilScoreThreshold = _newThreshold;
    }

    /**
     * @notice Update anomaly Z-score threshold
     * @param _newThreshold New threshold (× 100, e.g., 300 = 3.0)
     */
    function setAnomalyZScoreThreshold(uint256 _newThreshold) external onlyRole(ADMIN_ROLE) {
        anomalyZScoreThreshold = _newThreshold;
    }

    /**
     * @notice Update duplicate Hamming distance threshold
     * @param _newThreshold New threshold (number of bits)
     */
    function setDuplicateHammingThreshold(uint256 _newThreshold) external onlyRole(ADMIN_ROLE) {
        duplicateHammingThreshold = _newThreshold;
    }

    /**
     * @notice Update Chainlink oracle configuration
     * @param _adapterId External adapter ID
     * @param _fee Oracle fee in LINK
     */
    function setOracleConfig(
        bytes32 _adapterId,
        uint256 _fee
    ) external onlyRole(ADMIN_ROLE) {
        externalAdapterId = _adapterId;
        oracleFee = _fee;
    }

    // ============ View Functions ============

    /**
     * @notice Get fraud analysis for a submission
     * @param _submissionId Submission ID
     * @return FraudAnalysis struct
     */
    function getFraudAnalysis(uint256 _submissionId) external view returns (FraudAnalysis memory) {
        return fraudAnalyses[_submissionId];
    }

    /**
     * @notice Get submissions with matching perceptual hash
     * @param _hash Perceptual hash
     * @return Array of submission IDs
     */
    function getSubmissionsByHash(bytes32 _hash) external view returns (uint256[] memory) {
        return perceptualHashRegistry[_hash];
    }

    /**
     * @notice Get connected wallets for Sybil analysis
     * @param _user User address
     * @return Array of connected wallet addresses
     */
    function getConnectedWallets(address _user) external view returns (address[] memory) {
        return walletGraph[_user];
    }

    // ============ Utility Functions ============

    /**
     * @notice Convert uint to string
     */
    function uint2str(uint256 _i) private pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     * @notice Convert address to ASCII string
     */
    function toAsciiString(address _addr) private pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(_addr)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(abi.encodePacked("0x", s));
    }

    function char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
