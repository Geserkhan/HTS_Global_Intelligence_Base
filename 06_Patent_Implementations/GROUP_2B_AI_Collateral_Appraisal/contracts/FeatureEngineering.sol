// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title FeatureEngineering
 * @notice Extracts and encodes features from various data sources for ML model input
 * @dev Aggregates on-chain and oracle data into feature vectors
 */
contract FeatureEngineering {

    // ============ Structures ============

    struct PriceData {
        int256 price;
        uint256 timestamp;
        uint8 decimals;
    }

    struct MarketMetrics {
        uint256 volume24h;
        uint256 liquidity;
        uint256 volatility;      // Volatility index (0-100)
        uint256 marketCap;
        uint256 holders;
    }

    struct AssetMetadata {
        string name;
        string symbol;
        address contractAddress;
        uint256 totalSupply;
        uint256 createdAt;
        bool isVerified;
    }

    struct FeatureSet {
        uint256[] numericalFeatures;
        bytes32[] categoricalFeatures;
        uint256 featureVersion;
        uint256 timestamp;
    }

    // ============ State Variables ============

    mapping(address => PriceData) public assetPrices;
    mapping(address => MarketMetrics) public marketMetrics;
    mapping(address => AssetMetadata) public assetMetadata;
    mapping(address => FeatureSet) public assetFeatures;
    mapping(address => AggregatorV3Interface) public priceFeeds;

    address public admin;
    address public oracleUpdater;

    // Feature indices (for ML model)
    uint256 constant FEATURE_PRICE = 0;
    uint256 constant FEATURE_VOLUME = 1;
    uint256 constant FEATURE_LIQUIDITY = 2;
    uint256 constant FEATURE_VOLATILITY = 3;
    uint256 constant FEATURE_MARKET_CAP = 4;
    uint256 constant FEATURE_HOLDERS = 5;
    uint256 constant FEATURE_AGE_DAYS = 6;
    uint256 constant FEATURE_SUPPLY_RATIO = 7;
    uint256 constant FEATURE_PRICE_CHANGE_24H = 8;

    uint256 constant TOTAL_FEATURES = 9;

    // ============ Events ============

    event PriceUpdated(
        address indexed asset,
        int256 price,
        uint256 timestamp
    );

    event MarketMetricsUpdated(
        address indexed asset,
        uint256 volume,
        uint256 liquidity,
        uint256 volatility
    );

    event FeaturesExtracted(
        address indexed asset,
        uint256[] features,
        uint256 timestamp
    );

    event PriceFeedSet(
        address indexed asset,
        address priceFeed
    );

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracleUpdater || msg.sender == admin, "Only oracle");
        _;
    }

    // ============ Constructor ============

    constructor() {
        admin = msg.sender;
        oracleUpdater = msg.sender;
    }

    // ============ Price Data Functions ============

    /**
     * @notice Set Chainlink price feed for an asset
     * @param asset Asset address
     * @param priceFeed Chainlink price feed address
     */
    function setPriceFeed(
        address asset,
        address priceFeed
    ) external onlyAdmin {
        require(asset != address(0), "Invalid asset");
        require(priceFeed != address(0), "Invalid price feed");

        priceFeeds[asset] = AggregatorV3Interface(priceFeed);

        emit PriceFeedSet(asset, priceFeed);
    }

    /**
     * @notice Update price from Chainlink oracle
     * @param asset Asset address
     */
    function updatePriceFromOracle(address asset) public {
        AggregatorV3Interface priceFeed = priceFeeds[asset];
        require(address(priceFeed) != address(0), "No price feed");

        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(price > 0, "Invalid price");
        require(timeStamp > 0, "Invalid timestamp");

        assetPrices[asset] = PriceData({
            price: price,
            timestamp: timeStamp,
            decimals: priceFeed.decimals()
        });

        emit PriceUpdated(asset, price, timeStamp);
    }

    /**
     * @notice Manually update price (for assets without oracle)
     * @param asset Asset address
     * @param price Price value
     * @param decimals Price decimals
     */
    function updatePrice(
        address asset,
        int256 price,
        uint8 decimals
    ) external onlyOracle {
        require(price > 0, "Invalid price");

        assetPrices[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            decimals: decimals
        });

        emit PriceUpdated(asset, price, block.timestamp);
    }

    // ============ Market Metrics Functions ============

    /**
     * @notice Update market metrics for an asset
     * @param asset Asset address
     * @param volume24h 24-hour trading volume
     * @param liquidity Total liquidity
     * @param volatility Volatility index (0-100)
     * @param marketCap Market capitalization
     * @param holders Number of holders
     */
    function updateMarketMetrics(
        address asset,
        uint256 volume24h,
        uint256 liquidity,
        uint256 volatility,
        uint256 marketCap,
        uint256 holders
    ) external onlyOracle {
        require(volatility <= 100, "Invalid volatility");

        marketMetrics[asset] = MarketMetrics({
            volume24h: volume24h,
            liquidity: liquidity,
            volatility: volatility,
            marketCap: marketCap,
            holders: holders
        });

        emit MarketMetricsUpdated(asset, volume24h, liquidity, volatility);
    }

    /**
     * @notice Update asset metadata
     * @param asset Asset address
     * @param name Asset name
     * @param symbol Asset symbol
     * @param totalSupply Total supply
     * @param createdAt Creation timestamp
     * @param isVerified Whether contract is verified
     */
    function updateAssetMetadata(
        address asset,
        string calldata name,
        string calldata symbol,
        uint256 totalSupply,
        uint256 createdAt,
        bool isVerified
    ) external onlyOracle {
        assetMetadata[asset] = AssetMetadata({
            name: name,
            symbol: symbol,
            contractAddress: asset,
            totalSupply: totalSupply,
            createdAt: createdAt,
            isVerified: isVerified
        });
    }

    // ============ Feature Extraction ============

    /**
     * @notice Extract features for ML model
     * @param asset Asset address
     * @return features Array of numerical features
     */
    function extractFeatures(
        address asset
    ) external returns (uint256[] memory features) {
        // Update price if Chainlink feed available
        if (address(priceFeeds[asset]) != address(0)) {
            updatePriceFromOracle(asset);
        }

        features = new uint256[](TOTAL_FEATURES);

        PriceData memory priceData = assetPrices[asset];
        MarketMetrics memory metrics = marketMetrics[asset];
        AssetMetadata memory metadata = assetMetadata[asset];

        // Feature 0: Current price (normalized to 18 decimals)
        features[FEATURE_PRICE] = _normalizePrice(
            priceData.price,
            priceData.decimals
        );

        // Feature 1: 24h volume
        features[FEATURE_VOLUME] = metrics.volume24h;

        // Feature 2: Liquidity
        features[FEATURE_LIQUIDITY] = metrics.liquidity;

        // Feature 3: Volatility
        features[FEATURE_VOLATILITY] = metrics.volatility;

        // Feature 4: Market cap
        features[FEATURE_MARKET_CAP] = metrics.marketCap;

        // Feature 5: Number of holders
        features[FEATURE_HOLDERS] = metrics.holders;

        // Feature 6: Asset age in days
        features[FEATURE_AGE_DAYS] = (block.timestamp - metadata.createdAt) / 1 days;

        // Feature 7: Circulating supply ratio (if applicable)
        features[FEATURE_SUPPLY_RATIO] = metadata.totalSupply > 0
            ? (metrics.holders * 1e18) / metadata.totalSupply
            : 0;

        // Feature 8: Price change 24h (placeholder - would need historical data)
        features[FEATURE_PRICE_CHANGE_24H] = _calculatePriceChange(asset);

        // Store features
        bytes32[] memory categoricalFeatures = new bytes32[](1);
        categoricalFeatures[0] = keccak256(abi.encodePacked(metadata.symbol));

        assetFeatures[asset] = FeatureSet({
            numericalFeatures: features,
            categoricalFeatures: categoricalFeatures,
            featureVersion: 1,
            timestamp: block.timestamp
        });

        emit FeaturesExtracted(asset, features, block.timestamp);

        return features;
    }

    /**
     * @notice Encode features for ML model input
     * @param asset Asset address
     * @return encoded Encoded feature bytes
     */
    function encodeFeatures(
        address asset
    ) external view returns (bytes memory encoded) {
        FeatureSet memory featureSet = assetFeatures[asset];
        require(featureSet.timestamp > 0, "Features not extracted");

        return abi.encode(
            featureSet.numericalFeatures,
            featureSet.categoricalFeatures,
            featureSet.featureVersion,
            featureSet.timestamp
        );
    }

    /**
     * @notice Get normalized features for ML prediction
     * @param asset Asset address
     * @return normalizedFeatures Array of normalized features (0-1 range)
     */
    function getNormalizedFeatures(
        address asset
    ) external view returns (uint256[] memory normalizedFeatures) {
        FeatureSet memory featureSet = assetFeatures[asset];
        uint256[] memory features = featureSet.numericalFeatures;

        normalizedFeatures = new uint256[](features.length);

        // Normalization (simplified - in production use min-max scaling)
        for (uint256 i = 0; i < features.length; i++) {
            normalizedFeatures[i] = _normalize(features[i]);
        }

        return normalizedFeatures;
    }

    // ============ Helper Functions ============

    /**
     * @dev Normalize price to 18 decimals
     */
    function _normalizePrice(
        int256 price,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (price <= 0) return 0;

        uint256 absPrice = uint256(price);

        if (decimals == 18) {
            return absPrice;
        } else if (decimals < 18) {
            return absPrice * (10 ** (18 - decimals));
        } else {
            return absPrice / (10 ** (decimals - 18));
        }
    }

    /**
     * @dev Calculate 24h price change (simplified)
     */
    function _calculatePriceChange(
        address asset
    ) internal view returns (uint256) {
        // In production, would use historical price data
        // For now, return 0 (no change)
        return 0;
    }

    /**
     * @dev Normalize value to 0-1e18 range
     */
    function _normalize(uint256 value) internal pure returns (uint256) {
        // Simple normalization - in production use proper scaling
        if (value == 0) return 0;
        if (value > 1e18) return 1e18;
        return value;
    }

    // ============ View Functions ============

    /**
     * @notice Get price data for asset
     * @param asset Asset address
     * @return PriceData struct
     */
    function getPrice(address asset) external view returns (PriceData memory) {
        return assetPrices[asset];
    }

    /**
     * @notice Get market metrics for asset
     * @param asset Asset address
     * @return MarketMetrics struct
     */
    function getMarketMetrics(address asset) external view returns (MarketMetrics memory) {
        return marketMetrics[asset];
    }

    /**
     * @notice Get asset metadata
     * @param asset Asset address
     * @return AssetMetadata struct
     */
    function getAssetMetadata(address asset) external view returns (AssetMetadata memory) {
        return assetMetadata[asset];
    }

    /**
     * @notice Get feature set for asset
     * @param asset Asset address
     * @return FeatureSet struct
     */
    function getFeatures(address asset) external view returns (FeatureSet memory) {
        return assetFeatures[asset];
    }

    // ============ Admin Functions ============

    /**
     * @notice Update oracle updater address
     * @param newOracle New oracle address
     */
    function updateOracle(address newOracle) external onlyAdmin {
        require(newOracle != address(0), "Invalid oracle");
        oracleUpdater = newOracle;
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
