// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Layer1_BLXMultiRWAFeed
 * @notice Oracle and price feed aggregator for multiple Real World Asset (RWA) types
 * @dev Supports Gold, Real Estate, and Trade Finance collateral pricing
 *
 * @custom:security-contact security@htsdao.org
 * @custom:version 1.0.0
 */
contract Layer1_BLXMultiRWAFeed is AccessControl, Pausable {
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant PRICE_ADMIN_ROLE = keccak256("PRICE_ADMIN_ROLE");

    // ============ State Variables ============

    /// @notice Chainlink price feed for Gold (XAU/USD)
    AggregatorV3Interface public goldPriceFeed;

    /// @notice Chainlink price feed for USDC (USDC/USD)
    AggregatorV3Interface public usdcPriceFeed;

    /// @notice Maximum allowed price staleness (1 hour)
    uint256 public constant MAX_PRICE_AGE = 1 hours;

    /// @notice Liquidation threshold (125% LTV)
    uint256 public constant LIQUIDATION_THRESHOLD = 125;

    /// @notice Minimum collateral ratio (80% LTV for new loans)
    uint256 public constant MIN_COLLATERAL_RATIO = 80;

    // ============ Structs ============

    struct AssetPrice {
        uint256 price;          // Price in USD (8 decimals)
        uint256 timestamp;      // Last update timestamp
        uint256 confidence;     // Confidence score (0-100)
        address oracle;         // Oracle source address
    }

    struct UserPosition {
        uint256 collateralValue;    // Total collateral value (USD)
        uint256 debtValue;          // Total debt value (USD)
        uint256 ltv;                // Loan-to-Value ratio (percentage)
        bool isActive;              // Position active status
        uint256 lastUpdate;         // Last update timestamp
    }

    // ============ Storage Mappings ============

    /// @notice Asset type to price mapping
    mapping(bytes32 => AssetPrice) public assetPrices;

    /// @notice User address to position mapping
    mapping(address => UserPosition) public userPositions;

    /// @notice Custom oracle addresses for non-Chainlink assets
    mapping(bytes32 => address) public customOracles;

    /// @notice Asset type identifiers
    bytes32 public constant ASSET_GOLD = keccak256("BLX-GOLD");
    bytes32 public constant ASSET_PROPERTY = keccak256("BLX-PROPERTY");
    bytes32 public constant ASSET_TRADE = keccak256("BLX-TRADE");

    // ============ Events ============

    event PriceUpdated(
        bytes32 indexed assetType,
        uint256 price,
        uint256 timestamp,
        address oracle
    );

    event PositionUpdated(
        address indexed user,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 ltv
    );

    event OracleAdded(bytes32 indexed assetType, address oracle);

    event LiquidationThresholdMet(
        address indexed user,
        uint256 ltv,
        uint256 threshold
    );

    // ============ Constructor ============

    /**
     * @notice Initialize the BLX Multi-RWA Feed contract
     * @param _goldPriceFeed Chainlink Gold (XAU/USD) price feed address
     * @param _usdcPriceFeed Chainlink USDC (USDC/USD) price feed address
     * @param _admin Admin address for access control
     */
    constructor(
        address _goldPriceFeed,
        address _usdcPriceFeed,
        address _admin
    ) {
        require(_goldPriceFeed != address(0), "Invalid gold feed");
        require(_usdcPriceFeed != address(0), "Invalid USDC feed");
        require(_admin != address(0), "Invalid admin");

        goldPriceFeed = AggregatorV3Interface(_goldPriceFeed);
        usdcPriceFeed = AggregatorV3Interface(_usdcPriceFeed);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_UPDATER_ROLE, _admin);
        _grantRole(PRICE_ADMIN_ROLE, _admin);
    }

    // ============ Price Feed Functions ============

    /**
     * @notice Get current gold price from Chainlink oracle
     * @return price Current gold price (8 decimals)
     * @return timestamp Price update timestamp
     */
    function getGoldPrice() public view returns (uint256 price, uint256 timestamp) {
        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,

        ) = goldPriceFeed.latestRoundData();

        require(answer > 0, "Invalid gold price");
        require(block.timestamp - updatedAt <= MAX_PRICE_AGE, "Stale gold price");

        return (uint256(answer), updatedAt);
    }

    /**
     * @notice Get property value from custom oracle
     * @param tokenId Property NFT token ID
     * @return value Property value in USD (8 decimals)
     */
    function getPropertyValue(uint256 tokenId) public view returns (uint256 value) {
        address oracle = customOracles[ASSET_PROPERTY];
        require(oracle != address(0), "Property oracle not set");

        // Call custom oracle (interface depends on implementation)
        // For now, return stored value
        AssetPrice memory priceData = assetPrices[ASSET_PROPERTY];
        require(block.timestamp - priceData.timestamp <= MAX_PRICE_AGE, "Stale property price");

        return priceData.price;
    }

    /**
     * @notice Get trade finance instrument value
     * @param invoiceId Invoice/LC identifier
     * @return value Face value with discount applied (8 decimals)
     */
    function getTradeFinanceValue(bytes32 invoiceId) public view returns (uint256 value) {
        address oracle = customOracles[ASSET_TRADE];
        require(oracle != address(0), "Trade oracle not set");

        AssetPrice memory priceData = assetPrices[ASSET_TRADE];
        require(block.timestamp - priceData.timestamp <= MAX_PRICE_AGE, "Stale trade price");

        return priceData.price;
    }

    /**
     * @notice Update price for custom RWA asset
     * @param assetType Asset type identifier (PROPERTY, TRADE, etc.)
     * @param price New price in USD (8 decimals)
     * @param confidence Confidence score (0-100)
     */
    function updateAssetPrice(
        bytes32 assetType,
        uint256 price,
        uint256 confidence
    ) external onlyRole(ORACLE_UPDATER_ROLE) whenNotPaused {
        require(price > 0, "Invalid price");
        require(confidence <= 100, "Invalid confidence");

        assetPrices[assetType] = AssetPrice({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence,
            oracle: msg.sender
        });

        emit PriceUpdated(assetType, price, block.timestamp, msg.sender);
    }

    // ============ LTV Calculation Functions ============

    /**
     * @notice Calculate Loan-to-Value ratio for a user
     * @param user User address
     * @return ltv LTV percentage (e.g., 125 = 125%)
     */
    function calculateLTV(address user) public view returns (uint256 ltv) {
        UserPosition memory position = userPositions[user];

        if (!position.isActive || position.collateralValue == 0) {
            return 0;
        }

        // LTV = (Debt / Collateral) × 100
        ltv = (position.debtValue * 100) / position.collateralValue;

        return ltv;
    }

    /**
     * @notice Check if user position exceeds liquidation threshold
     * @param user User address
     * @return shouldLiquidate True if LTV > 125%
     */
    function isLiquidatable(address user) public view returns (bool shouldLiquidate) {
        uint256 ltv = calculateLTV(user);
        return ltv > LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Update user position data
     * @param user User address
     * @param collateralValue Total collateral value in USD
     * @param debtValue Total debt value in USD
     */
    function updateUserPosition(
        address user,
        uint256 collateralValue,
        uint256 debtValue
    ) external onlyRole(ORACLE_UPDATER_ROLE) whenNotPaused {
        require(user != address(0), "Invalid user");

        uint256 ltv = 0;
        if (collateralValue > 0) {
            ltv = (debtValue * 100) / collateralValue;
        }

        userPositions[user] = UserPosition({
            collateralValue: collateralValue,
            debtValue: debtValue,
            ltv: ltv,
            isActive: collateralValue > 0 && debtValue > 0,
            lastUpdate: block.timestamp
        });

        emit PositionUpdated(user, collateralValue, debtValue, ltv);

        if (ltv > LIQUIDATION_THRESHOLD) {
            emit LiquidationThresholdMet(user, ltv, LIQUIDATION_THRESHOLD);
        }
    }

    // ============ Oracle Management ============

    /**
     * @notice Add or update custom oracle for asset type
     * @param assetType Asset type identifier
     * @param oracle Oracle contract address
     */
    function addCustomOracle(
        bytes32 assetType,
        address oracle
    ) external onlyRole(PRICE_ADMIN_ROLE) {
        require(oracle != address(0), "Invalid oracle");
        customOracles[assetType] = oracle;
        emit OracleAdded(assetType, oracle);
    }

    // ============ Admin Functions ============

    /**
     * @notice Pause contract (emergency use)
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get user position details
     * @param user User address
     * @return position UserPosition struct
     */
    function getUserPosition(address user) external view returns (UserPosition memory position) {
        return userPositions[user];
    }

    /**
     * @notice Get asset price details
     * @param assetType Asset type identifier
     * @return priceData AssetPrice struct
     */
    function getAssetPrice(bytes32 assetType) external view returns (AssetPrice memory priceData) {
        return assetPrices[assetType];
    }

    /**
     * @notice Check if price data is stale
     * @param assetType Asset type identifier
     * @return isStale True if price older than MAX_PRICE_AGE
     */
    function isPriceStale(bytes32 assetType) public view returns (bool isStale) {
        AssetPrice memory priceData = assetPrices[assetType];
        return block.timestamp - priceData.timestamp > MAX_PRICE_AGE;
    }
}
