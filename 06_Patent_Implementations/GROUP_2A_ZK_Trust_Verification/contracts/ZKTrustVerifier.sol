// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ZKTrustVerifier
 * @notice Zero-Knowledge Trust Verification Engine for privacy-preserving identity and credential verification
 * @dev Implements zk-SNARK verification for trust scores without revealing underlying data
 */
contract ZKTrustVerifier {

    // ============ State Variables ============

    struct ProofData {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    struct TrustScore {
        uint256 score;
        uint256 timestamp;
        bytes32 proofHash;
        bool isValid;
    }

    struct VerificationCircuit {
        bytes32 circuitId;
        address verifierContract;
        uint256 minThreshold;
        bool isActive;
    }

    // Mapping: user address => trust score
    mapping(address => TrustScore) public trustScores;

    // Mapping: circuit ID => circuit configuration
    mapping(bytes32 => VerificationCircuit) public circuits;

    // Mapping: proof hash => used status (prevent replay)
    mapping(bytes32 => bool) public usedProofs;

    // Witness commitments
    mapping(address => bytes32) public witnessCommitments;

    // Trust threshold for various operations
    uint256 public constant MIN_TRUST_SCORE = 70;
    uint256 public constant MAX_TRUST_SCORE = 100;

    address public admin;
    uint256 public verificationCount;

    // ============ Events ============

    event TrustScoreVerified(
        address indexed user,
        uint256 score,
        bytes32 proofHash,
        uint256 timestamp
    );

    event CircuitRegistered(
        bytes32 indexed circuitId,
        address verifierContract,
        uint256 minThreshold
    );

    event WitnessCommitted(
        address indexed user,
        bytes32 commitment,
        uint256 timestamp
    );

    event ProofVerified(
        address indexed user,
        bytes32 indexed circuitId,
        bool success
    );

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier validScore(uint256 score) {
        require(score >= MIN_TRUST_SCORE && score <= MAX_TRUST_SCORE, "Invalid score");
        _;
    }

    modifier circuitActive(bytes32 circuitId) {
        require(circuits[circuitId].isActive, "Circuit not active");
        _;
    }

    // ============ Constructor ============

    constructor() {
        admin = msg.sender;
    }

    // ============ Core Functions ============

    /**
     * @notice Register a new ZK verification circuit
     * @param circuitId Unique identifier for the circuit
     * @param verifierContract Address of the verifier contract
     * @param minThreshold Minimum trust score threshold
     */
    function registerCircuit(
        bytes32 circuitId,
        address verifierContract,
        uint256 minThreshold
    ) external onlyAdmin {
        require(verifierContract != address(0), "Invalid verifier");
        require(minThreshold >= MIN_TRUST_SCORE, "Threshold too low");

        circuits[circuitId] = VerificationCircuit({
            circuitId: circuitId,
            verifierContract: verifierContract,
            minThreshold: minThreshold,
            isActive: true
        });

        emit CircuitRegistered(circuitId, verifierContract, minThreshold);
    }

    /**
     * @notice Commit a witness for future verification
     * @param commitment Hash commitment of the witness data
     */
    function commitWitness(bytes32 commitment) external {
        require(commitment != bytes32(0), "Invalid commitment");

        witnessCommitments[msg.sender] = commitment;

        emit WitnessCommitted(msg.sender, commitment, block.timestamp);
    }

    /**
     * @notice Verify a zero-knowledge proof and update trust score
     * @param circuitId ID of the verification circuit to use
     * @param proof ZK proof data
     * @param publicInputs Public inputs for verification
     * @param trustScore Claimed trust score
     */
    function verifyProof(
        bytes32 circuitId,
        ProofData calldata proof,
        uint256[] calldata publicInputs,
        uint256 trustScore
    ) external circuitActive(circuitId) validScore(trustScore) {

        // Generate proof hash
        bytes32 proofHash = keccak256(abi.encodePacked(
            proof.a,
            proof.b,
            proof.c,
            publicInputs,
            msg.sender,
            block.timestamp
        ));

        // Prevent proof replay
        require(!usedProofs[proofHash], "Proof already used");

        VerificationCircuit memory circuit = circuits[circuitId];

        // Call external verifier contract
        bool isValid = _callVerifier(
            circuit.verifierContract,
            proof,
            publicInputs
        );

        require(isValid, "Proof verification failed");
        require(trustScore >= circuit.minThreshold, "Score below threshold");

        // Mark proof as used
        usedProofs[proofHash] = true;

        // Update trust score
        trustScores[msg.sender] = TrustScore({
            score: trustScore,
            timestamp: block.timestamp,
            proofHash: proofHash,
            isValid: true
        });

        verificationCount++;

        emit TrustScoreVerified(msg.sender, trustScore, proofHash, block.timestamp);
        emit ProofVerified(msg.sender, circuitId, true);
    }

    /**
     * @notice Batch verify multiple proofs for efficiency
     * @param circuitId ID of the verification circuit
     * @param proofs Array of proof data
     * @param publicInputsArray Array of public inputs
     * @param trustScores Array of trust scores
     * @param users Array of user addresses
     */
    function batchVerifyProofs(
        bytes32 circuitId,
        ProofData[] calldata proofs,
        uint256[][] calldata publicInputsArray,
        uint256[] calldata trustScores,
        address[] calldata users
    ) external circuitActive(circuitId) {
        require(
            proofs.length == publicInputsArray.length &&
            proofs.length == trustScores.length &&
            proofs.length == users.length,
            "Array length mismatch"
        );

        VerificationCircuit memory circuit = circuits[circuitId];

        for (uint256 i = 0; i < proofs.length; i++) {
            require(
                trustScores[i] >= MIN_TRUST_SCORE &&
                trustScores[i] <= MAX_TRUST_SCORE,
                "Invalid score"
            );

            bytes32 proofHash = keccak256(abi.encodePacked(
                proofs[i].a,
                proofs[i].b,
                proofs[i].c,
                publicInputsArray[i],
                users[i],
                block.timestamp
            ));

            require(!usedProofs[proofHash], "Proof already used");

            bool isValid = _callVerifier(
                circuit.verifierContract,
                proofs[i],
                publicInputsArray[i]
            );

            if (isValid && trustScores[i] >= circuit.minThreshold) {
                usedProofs[proofHash] = true;

                // Update trust score
                trustScores[users[i]] = TrustScore({
                    score: trustScores[i],
                    timestamp: block.timestamp,
                    proofHash: proofHash,
                    isValid: true
                });

                verificationCount++;

                emit TrustScoreVerified(users[i], trustScores[i], proofHash, block.timestamp);
            }
        }
    }

    /**
     * @notice Verify witness against commitment
     * @param user Address of the user
     * @param witness The actual witness data
     * @return bool Whether witness matches commitment
     */
    function verifyWitness(
        address user,
        bytes32 witness
    ) public view returns (bool) {
        bytes32 commitment = witnessCommitments[user];
        require(commitment != bytes32(0), "No commitment found");

        return keccak256(abi.encodePacked(witness)) == commitment;
    }

    /**
     * @notice Get trust score for a user
     * @param user Address of the user
     * @return TrustScore struct
     */
    function getTrustScore(address user) external view returns (TrustScore memory) {
        return trustScores[user];
    }

    /**
     * @notice Check if user meets minimum trust threshold
     * @param user Address to check
     * @return bool Whether user meets threshold
     */
    function isTrusted(address user) external view returns (bool) {
        TrustScore memory score = trustScores[user];
        return score.isValid &&
               score.score >= MIN_TRUST_SCORE &&
               block.timestamp - score.timestamp < 30 days; // Score valid for 30 days
    }

    /**
     * @notice Invalidate a trust score (e.g., if fraud detected)
     * @param user Address of the user
     */
    function invalidateTrustScore(address user) external onlyAdmin {
        trustScores[user].isValid = false;
    }

    /**
     * @notice Deactivate a circuit
     * @param circuitId ID of the circuit to deactivate
     */
    function deactivateCircuit(bytes32 circuitId) external onlyAdmin {
        circuits[circuitId].isActive = false;
    }

    // ============ Internal Functions ============

    /**
     * @dev Call external verifier contract
     * @param verifier Address of verifier contract
     * @param proof Proof data
     * @param publicInputs Public inputs
     * @return bool Verification result
     */
    function _callVerifier(
        address verifier,
        ProofData calldata proof,
        uint256[] calldata publicInputs
    ) internal view returns (bool) {
        // In production, this would call the actual zk-SNARK verifier
        // For demonstration, we'll use a simplified verification

        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[])",
                proof.a,
                proof.b,
                proof.c,
                publicInputs
            )
        );

        if (!success) {
            return false;
        }

        return abi.decode(data, (bool));
    }

    /**
     * @notice Update admin address
     * @param newAdmin New admin address
     */
    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin");
        admin = newAdmin;
    }
}
