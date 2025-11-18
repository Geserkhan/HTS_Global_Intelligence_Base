// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WitnessGenerator
 * @notice Generates and manages witness data for ZK proof generation
 * @dev Handles private inputs and witness commitments for trust score verification
 */
contract WitnessGenerator {

    // ============ Structures ============

    struct WitnessData {
        bytes32 commitment;
        uint256 timestamp;
        bool isRevealed;
        bytes32 merkleRoot;
    }

    struct CredentialWitness {
        uint256 credentialType;  // 1=KYC, 2=AML, 3=Credit Score, etc.
        uint256 score;
        uint256 issuedAt;
        bytes32 issuerHash;
        bool isValid;
    }

    struct AggregatedWitness {
        bytes32[] credentialHashes;
        uint256 totalScore;
        uint256 credentialCount;
        bytes32 aggregateCommitment;
    }

    // ============ State Variables ============

    mapping(address => WitnessData) public userWitnesses;
    mapping(address => mapping(uint256 => CredentialWitness)) public credentials;
    mapping(address => AggregatedWitness) public aggregatedWitnesses;
    mapping(bytes32 => bool) public validMerkleRoots;

    address public zkVerifierContract;
    address public admin;

    uint256 public constant CREDENTIAL_TYPE_KYC = 1;
    uint256 public constant CREDENTIAL_TYPE_AML = 2;
    uint256 public constant CREDENTIAL_TYPE_CREDIT = 3;
    uint256 public constant CREDENTIAL_TYPE_REPUTATION = 4;

    // ============ Events ============

    event WitnessCommitted(
        address indexed user,
        bytes32 commitment,
        bytes32 merkleRoot,
        uint256 timestamp
    );

    event CredentialAdded(
        address indexed user,
        uint256 indexed credentialType,
        uint256 score,
        bytes32 issuerHash
    );

    event WitnessRevealed(
        address indexed user,
        bytes32 commitment,
        uint256 timestamp
    );

    event AggregateWitnessGenerated(
        address indexed user,
        uint256 totalScore,
        uint256 credentialCount
    );

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyVerifier() {
        require(msg.sender == zkVerifierContract, "Only verifier");
        _;
    }

    // ============ Constructor ============

    constructor(address _zkVerifierContract) {
        admin = msg.sender;
        zkVerifierContract = _zkVerifierContract;
    }

    // ============ Core Functions ============

    /**
     * @notice Generate and commit witness data for a user
     * @param user Address of the user
     * @param privateData Hash of private credential data
     * @param merkleRoot Merkle root of credential tree
     * @return commitment Witness commitment hash
     */
    function generateWitness(
        address user,
        bytes32 privateData,
        bytes32 merkleRoot
    ) external onlyVerifier returns (bytes32 commitment) {
        // Generate commitment using Pedersen-like commitment
        commitment = keccak256(abi.encodePacked(
            user,
            privateData,
            merkleRoot,
            block.timestamp,
            block.number
        ));

        userWitnesses[user] = WitnessData({
            commitment: commitment,
            timestamp: block.timestamp,
            isRevealed: false,
            merkleRoot: merkleRoot
        });

        validMerkleRoots[merkleRoot] = true;

        emit WitnessCommitted(user, commitment, merkleRoot, block.timestamp);

        return commitment;
    }

    /**
     * @notice Add a credential to user's witness data
     * @param user Address of the user
     * @param credentialType Type of credential (KYC, AML, etc.)
     * @param score Score value for this credential
     * @param issuerHash Hash of the issuer's identity
     */
    function addCredential(
        address user,
        uint256 credentialType,
        uint256 score,
        bytes32 issuerHash
    ) external onlyAdmin {
        require(credentialType > 0 && credentialType <= 4, "Invalid credential type");
        require(score > 0 && score <= 100, "Invalid score");

        credentials[user][credentialType] = CredentialWitness({
            credentialType: credentialType,
            score: score,
            issuedAt: block.timestamp,
            issuerHash: issuerHash,
            isValid: true
        });

        emit CredentialAdded(user, credentialType, score, issuerHash);
    }

    /**
     * @notice Generate aggregated witness from multiple credentials
     * @param user Address of the user
     * @param credentialTypes Array of credential types to aggregate
     * @return aggregateCommitment Commitment to aggregated data
     */
    function generateAggregateWitness(
        address user,
        uint256[] calldata credentialTypes
    ) external returns (bytes32 aggregateCommitment) {
        require(credentialTypes.length > 0, "No credentials provided");

        bytes32[] memory credentialHashes = new bytes32[](credentialTypes.length);
        uint256 totalScore = 0;
        uint256 validCredentials = 0;

        for (uint256 i = 0; i < credentialTypes.length; i++) {
            CredentialWitness memory cred = credentials[user][credentialTypes[i]];

            if (cred.isValid) {
                credentialHashes[validCredentials] = keccak256(abi.encodePacked(
                    cred.credentialType,
                    cred.score,
                    cred.issuedAt,
                    cred.issuerHash
                ));

                totalScore += cred.score;
                validCredentials++;
            }
        }

        require(validCredentials > 0, "No valid credentials");

        // Average score across credentials
        uint256 averageScore = totalScore / validCredentials;

        aggregateCommitment = keccak256(abi.encodePacked(
            user,
            credentialHashes,
            averageScore,
            validCredentials,
            block.timestamp
        ));

        aggregatedWitnesses[user] = AggregatedWitness({
            credentialHashes: credentialHashes,
            totalScore: averageScore,
            credentialCount: validCredentials,
            aggregateCommitment: aggregateCommitment
        });

        emit AggregateWitnessGenerated(user, averageScore, validCredentials);

        return aggregateCommitment;
    }

    /**
     * @notice Compute Merkle root from credential hashes
     * @param leaves Array of credential hashes
     * @return root Merkle root
     */
    function computeMerkleRoot(bytes32[] memory leaves) public pure returns (bytes32 root) {
        require(leaves.length > 0, "Empty leaves array");

        uint256 n = leaves.length;
        uint256 offset = 0;

        while (n > 0) {
            for (uint256 i = 0; i < n - 1; i += 2) {
                leaves[offset + i / 2] = _hashPair(
                    leaves[offset + i],
                    leaves[offset + i + 1]
                );
            }

            if (n % 2 == 1) {
                leaves[offset + n / 2] = leaves[offset + n - 1];
            }

            offset += n / 2;
            n = (n + 1) / 2;
        }

        return leaves[leaves.length - 1];
    }

    /**
     * @notice Verify Merkle proof for a credential
     * @param leaf Leaf hash (credential hash)
     * @param proof Array of sibling hashes
     * @param root Expected Merkle root
     * @return bool Whether proof is valid
     */
    function verifyMerkleProof(
        bytes32 leaf,
        bytes32[] memory proof,
        bytes32 root
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }

        return computedHash == root;
    }

    /**
     * @notice Prepare public inputs for ZK circuit
     * @param user Address of the user
     * @return publicInputs Array of public inputs
     */
    function preparePublicInputs(
        address user
    ) external view returns (uint256[] memory publicInputs) {
        WitnessData memory witness = userWitnesses[user];
        AggregatedWitness memory aggWitness = aggregatedWitnesses[user];

        publicInputs = new uint256[](4);
        publicInputs[0] = uint256(uint160(user));
        publicInputs[1] = uint256(witness.commitment);
        publicInputs[2] = aggWitness.totalScore;
        publicInputs[3] = witness.timestamp;

        return publicInputs;
    }

    /**
     * @notice Reveal witness (for verification purposes only)
     * @param user Address of the user
     */
    function revealWitness(address user) external onlyVerifier {
        WitnessData storage witness = userWitnesses[user];
        require(!witness.isRevealed, "Already revealed");

        witness.isRevealed = true;

        emit WitnessRevealed(user, witness.commitment, block.timestamp);
    }

    /**
     * @notice Invalidate a credential
     * @param user Address of the user
     * @param credentialType Type of credential to invalidate
     */
    function invalidateCredential(
        address user,
        uint256 credentialType
    ) external onlyAdmin {
        credentials[user][credentialType].isValid = false;
    }

    /**
     * @notice Get credential details
     * @param user Address of the user
     * @param credentialType Type of credential
     * @return CredentialWitness struct
     */
    function getCredential(
        address user,
        uint256 credentialType
    ) external view returns (CredentialWitness memory) {
        return credentials[user][credentialType];
    }

    /**
     * @notice Get aggregated witness data
     * @param user Address of the user
     * @return AggregatedWitness struct
     */
    function getAggregatedWitness(
        address user
    ) external view returns (AggregatedWitness memory) {
        return aggregatedWitnesses[user];
    }

    /**
     * @notice Check if witness commitment is valid
     * @param user Address of the user
     * @param commitment Commitment to verify
     * @return bool Whether commitment is valid
     */
    function verifyCommitment(
        address user,
        bytes32 commitment
    ) external view returns (bool) {
        return userWitnesses[user].commitment == commitment;
    }

    // ============ Internal Functions ============

    /**
     * @dev Hash two leaves together
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /**
     * @notice Update verifier contract address
     * @param newVerifier New verifier address
     */
    function updateVerifier(address newVerifier) external onlyAdmin {
        require(newVerifier != address(0), "Invalid verifier");
        zkVerifierContract = newVerifier;
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
