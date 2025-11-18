// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AICollateralAppraisal
 * @notice AI-powered collateral auto-appraisal system for dynamic risk assessment
 * @dev Integrates ML models for real-time collateral valuation and risk scoring
 */
contract AICollateralAppraisal {

    // ============ Structures ============

    struct CollateralAsset {
        address assetAddress;
        uint256 tokenId;          // For NFTs, 0 for fungible tokens
        AssetType assetType;
        uint256 appraisedValue;   // In USD (scaled by 1e18)
        uint256 confidenceScore;  // 0-100
        uint256 riskScore;        // 0-100 (higher = riskier)
        uint256 timestamp;
        bytes32 mlModelHash;      // Hash of ML model used
        bool isActive;
    }

    struct AppraisalRequest {
        uint256 requestId;
        address requester;
        address assetAddress;
        uint256 tokenId;
        AssetType assetType;
        AppraisalStatus status;
        uint256 requestedAt;
        uint256 completedAt;
    }

    struct MLModel {
        bytes32 modelHash;
        string modelURI;          // IPFS/Arweave URI to model
        uint256 version;
        uint256 accuracy;         // Backtested accuracy (0-100)
        bool isActive;
        uint256 deployedAt;
    }

    struct RiskPolicy {
        uint256 maxLTV;           // Max loan-to-value (in basis points, 7500 = 75%)
        uint256 minConfidence;    // Min confidence score required
        uint256 maxRiskScore;     // Max acceptable risk score
        uint256 appraisalValidityPeriod; // How long appraisal is valid (seconds)
    }

    struct FeatureVector {
        uint256[] features;       // Encoded features for ML model
        bytes32 featureHash;
    }

    enum AssetType {
        ERC20,
        ERC721,
        ERC1155,
        RWA,
        LP_TOKEN,
        YIELD_BEARING
    }

    enum AppraisalStatus {
        Pending,
        Processing,
        Completed,
        Failed
    }

    // ============ State Variables ============

    mapping(bytes32 => CollateralAsset) public collateralAssets;
    mapping(uint256 => AppraisalRequest) public appraisalRequests;
    mapping(bytes32 => MLModel) public mlModels;
    mapping(AssetType => RiskPolicy) public riskPolicies;
    mapping(address => FeatureVector) public assetFeatures;

    bytes32 public activeModelHash;
    uint256 public requestCounter;
    address public oracle;
    address public admin;

    uint256 public constant CONFIDENCE_THRESHOLD = 70;
    uint256 public constant MAX_RISK_SCORE = 80;
    uint256 public constant APPRAISAL_VALIDITY = 24 hours;

    // ============ Events ============

    event AppraisalRequested(
        uint256 indexed requestId,
        address indexed requester,
        address assetAddress,
        uint256 tokenId,
        AssetType assetType
    );

    event AppraisalCompleted(
        uint256 indexed requestId,
        bytes32 indexed assetKey,
        uint256 appraisedValue,
        uint256 confidenceScore,
        uint256 riskScore
    );

    event MLModelDeployed(
        bytes32 indexed modelHash,
        string modelURI,
        uint256 version,
        uint256 accuracy
    );

    event RiskPolicyUpdated(
        AssetType indexed assetType,
        uint256 maxLTV,
        uint256 minConfidence,
        uint256 maxRiskScore
    );

    event FeatureVectorUpdated(
        address indexed assetAddress,
        bytes32 featureHash
    );

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle");
        _;
    }

    modifier validAsset(address assetAddress) {
        require(assetAddress != address(0), "Invalid asset");
        _;
    }

    // ============ Constructor ============

    constructor(address _oracle) {
        admin = msg.sender;
        oracle = _oracle;

        // Initialize default risk policies
        _initializeRiskPolicies();
    }

    function _initializeRiskPolicies() private {
        riskPolicies[AssetType.ERC20] = RiskPolicy({
            maxLTV: 7500,                    // 75%
            minConfidence: 70,
            maxRiskScore: 60,
            appraisalValidityPeriod: 24 hours
        });

        riskPolicies[AssetType.ERC721] = RiskPolicy({
            maxLTV: 5000,                    // 50%
            minConfidence: 75,
            maxRiskScore: 70,
            appraisalValidityPeriod: 12 hours
        });

        riskPolicies[AssetType.RWA] = RiskPolicy({
            maxLTV: 6000,                    // 60%
            minConfidence: 80,
            maxRiskScore: 50,
            appraisalValidityPeriod: 6 hours
        });
    }

    // ============ Core Functions ============

    /**
     * @notice Request appraisal for a collateral asset
     * @param assetAddress Address of the asset contract
     * @param tokenId Token ID (for NFTs)
     * @param assetType Type of asset
     * @return requestId Unique request identifier
     */
    function requestAppraisal(
        address assetAddress,
        uint256 tokenId,
        AssetType assetType
    ) external validAsset(assetAddress) returns (uint256 requestId) {
        requestId = ++requestCounter;

        appraisalRequests[requestId] = AppraisalRequest({
            requestId: requestId,
            requester: msg.sender,
            assetAddress: assetAddress,
            tokenId: tokenId,
            assetType: assetType,
            status: AppraisalStatus.Pending,
            requestedAt: block.timestamp,
            completedAt: 0
        });

        emit AppraisalRequested(
            requestId,
            msg.sender,
            assetAddress,
            tokenId,
            assetType
        );

        return requestId;
    }

    /**
     * @notice Submit appraisal result from AI oracle
     * @param requestId Request ID to fulfill
     * @param appraisedValue Appraised value in USD
     * @param confidenceScore Confidence of appraisal (0-100)
     * @param riskScore Risk score (0-100)
     * @param modelHash Hash of ML model used
     */
    function submitAppraisal(
        uint256 requestId,
        uint256 appraisedValue,
        uint256 confidenceScore,
        uint256 riskScore,
        bytes32 modelHash
    ) external onlyOracle {
        AppraisalRequest storage request = appraisalRequests[requestId];
        require(request.status == AppraisalStatus.Pending, "Invalid status");
        require(confidenceScore <= 100, "Invalid confidence");
        require(riskScore <= 100, "Invalid risk score");

        bytes32 assetKey = _getAssetKey(
            request.assetAddress,
            request.tokenId
        );

        collateralAssets[assetKey] = CollateralAsset({
            assetAddress: request.assetAddress,
            tokenId: request.tokenId,
            assetType: request.assetType,
            appraisedValue: appraisedValue,
            confidenceScore: confidenceScore,
            riskScore: riskScore,
            timestamp: block.timestamp,
            mlModelHash: modelHash,
            isActive: true
        });

        request.status = AppraisalStatus.Completed;
        request.completedAt = block.timestamp;

        emit AppraisalCompleted(
            requestId,
            assetKey,
            appraisedValue,
            confidenceScore,
            riskScore
        );
    }

    /**
     * @notice Get appraisal for an asset
     * @param assetAddress Address of the asset
     * @param tokenId Token ID (0 for fungible)
     * @return CollateralAsset struct
     */
    function getAppraisal(
        address assetAddress,
        uint256 tokenId
    ) external view returns (CollateralAsset memory) {
        bytes32 assetKey = _getAssetKey(assetAddress, tokenId);
        return collateralAssets[assetKey];
    }

    /**
     * @notice Check if appraisal is valid and meets risk policy
     * @param assetAddress Address of the asset
     * @param tokenId Token ID
     * @return isValid Whether appraisal meets requirements
     * @return maxBorrowAmount Maximum amount that can be borrowed
     */
    function validateAppraisal(
        address assetAddress,
        uint256 tokenId
    ) external view returns (bool isValid, uint256 maxBorrowAmount) {
        bytes32 assetKey = _getAssetKey(assetAddress, tokenId);
        CollateralAsset memory asset = collateralAssets[assetKey];

        if (!asset.isActive) {
            return (false, 0);
        }

        RiskPolicy memory policy = riskPolicies[asset.assetType];

        // Check if appraisal is still valid (not expired)
        if (block.timestamp - asset.timestamp > policy.appraisalValidityPeriod) {
            return (false, 0);
        }

        // Check confidence and risk scores
        if (asset.confidenceScore < policy.minConfidence ||
            asset.riskScore > policy.maxRiskScore) {
            return (false, 0);
        }

        // Calculate max borrow amount based on LTV
        maxBorrowAmount = (asset.appraisedValue * policy.maxLTV) / 10000;

        return (true, maxBorrowAmount);
    }

    /**
     * @notice Deploy a new ML model
     * @param modelHash Hash of the model
     * @param modelURI URI to model (IPFS/Arweave)
     * @param version Version number
     * @param accuracy Backtested accuracy
     */
    function deployMLModel(
        bytes32 modelHash,
        string calldata modelURI,
        uint256 version,
        uint256 accuracy
    ) external onlyAdmin {
        require(accuracy <= 100, "Invalid accuracy");
        require(bytes(modelURI).length > 0, "Invalid URI");

        mlModels[modelHash] = MLModel({
            modelHash: modelHash,
            modelURI: modelURI,
            version: version,
            accuracy: accuracy,
            isActive: true,
            deployedAt: block.timestamp
        });

        activeModelHash = modelHash;

        emit MLModelDeployed(modelHash, modelURI, version, accuracy);
    }

    /**
     * @notice Update risk policy for an asset type
     * @param assetType Type of asset
     * @param maxLTV Maximum loan-to-value (basis points)
     * @param minConfidence Minimum confidence score
     * @param maxRiskScore Maximum risk score
     * @param validityPeriod Appraisal validity period
     */
    function updateRiskPolicy(
        AssetType assetType,
        uint256 maxLTV,
        uint256 minConfidence,
        uint256 maxRiskScore,
        uint256 validityPeriod
    ) external onlyAdmin {
        require(maxLTV <= 10000, "LTV too high");
        require(minConfidence <= 100, "Invalid confidence");
        require(maxRiskScore <= 100, "Invalid risk score");

        riskPolicies[assetType] = RiskPolicy({
            maxLTV: maxLTV,
            minConfidence: minConfidence,
            maxRiskScore: maxRiskScore,
            appraisalValidityPeriod: validityPeriod
        });

        emit RiskPolicyUpdated(
            assetType,
            maxLTV,
            minConfidence,
            maxRiskScore
        );
    }

    /**
     * @notice Update feature vector for an asset (used by ML model)
     * @param assetAddress Address of the asset
     * @param features Array of feature values
     */
    function updateFeatureVector(
        address assetAddress,
        uint256[] calldata features
    ) external onlyOracle {
        bytes32 featureHash = keccak256(abi.encodePacked(features));

        assetFeatures[assetAddress] = FeatureVector({
            features: features,
            featureHash: featureHash
        });

        emit FeatureVectorUpdated(assetAddress, featureHash);
    }

    /**
     * @notice Batch appraisal for multiple assets
     * @param assetAddresses Array of asset addresses
     * @param tokenIds Array of token IDs
     * @param assetTypes Array of asset types
     * @return requestIds Array of request IDs
     */
    function batchRequestAppraisal(
        address[] calldata assetAddresses,
        uint256[] calldata tokenIds,
        AssetType[] calldata assetTypes
    ) external returns (uint256[] memory requestIds) {
        require(
            assetAddresses.length == tokenIds.length &&
            assetAddresses.length == assetTypes.length,
            "Array length mismatch"
        );

        requestIds = new uint256[](assetAddresses.length);

        for (uint256 i = 0; i < assetAddresses.length; i++) {
            requestIds[i] = ++requestCounter;

            appraisalRequests[requestIds[i]] = AppraisalRequest({
                requestId: requestIds[i],
                requester: msg.sender,
                assetAddress: assetAddresses[i],
                tokenId: tokenIds[i],
                assetType: assetTypes[i],
                status: AppraisalStatus.Pending,
                requestedAt: block.timestamp,
                completedAt: 0
            });

            emit AppraisalRequested(
                requestIds[i],
                msg.sender,
                assetAddresses[i],
                tokenIds[i],
                assetTypes[i]
            );
        }

        return requestIds;
    }

    /**
     * @notice Invalidate an appraisal (e.g., if fraud detected)
     * @param assetAddress Address of the asset
     * @param tokenId Token ID
     */
    function invalidateAppraisal(
        address assetAddress,
        uint256 tokenId
    ) external onlyAdmin {
        bytes32 assetKey = _getAssetKey(assetAddress, tokenId);
        collateralAssets[assetKey].isActive = false;
    }

    /**
     * @notice Get current active ML model
     * @return MLModel struct
     */
    function getActiveModel() external view returns (MLModel memory) {
        return mlModels[activeModelHash];
    }

    /**
     * @notice Get risk policy for asset type
     * @param assetType Type of asset
     * @return RiskPolicy struct
     */
    function getRiskPolicy(
        AssetType assetType
    ) external view returns (RiskPolicy memory) {
        return riskPolicies[assetType];
    }

    /**
     * @notice Get feature vector for an asset
     * @param assetAddress Address of the asset
     * @return features Array of features
     */
    function getFeatureVector(
        address assetAddress
    ) external view returns (uint256[] memory features) {
        return assetFeatures[assetAddress].features;
    }

    // ============ Internal Functions ============

    /**
     * @dev Generate unique key for asset
     */
    function _getAssetKey(
        address assetAddress,
        uint256 tokenId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetAddress, tokenId));
    }

    /**
     * @notice Update oracle address
     * @param newOracle New oracle address
     */
    function updateOracle(address newOracle) external onlyAdmin {
        require(newOracle != address(0), "Invalid oracle");
        oracle = newOracle;
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
