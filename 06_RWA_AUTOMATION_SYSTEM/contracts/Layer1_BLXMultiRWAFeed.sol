// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BLXMultiRWAFeed
 * @notice Layer 1: Multi-RWA Feed Contract
 * @dev Aggregates real-world asset data from Bloomberg, Asset Managers, and LBMA
 */
contract BLXMultiRWAFeed is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Asset types
    enum AssetType {
        US_TREASURIES,    // 30% weight
        PRIVATE_CREDIT,   // 20% weight
        GOLD              // 50% weight
    }

    // Data source
    enum DataSource {
        BLOOMBERG,
        ASSET_MANAGER,
        LBMA
    }

    struct AssetData {
        uint256 price;           // Asset price in USD (18 decimals)
        uint256 timestamp;       // Last update timestamp
        uint256 weight;          // Weight in basket (basis points, 10000 = 100%)
        DataSource source;       // Data source
        bool isActive;           // Active status
        uint256 lastUpdate;      // Block number of last update
    }

    struct BasketValue {
        uint256 totalValue;      // Total basket value
        uint256 timestamp;       // Calculation timestamp
        uint256 usTreasuriesValue;
        uint256 privateCreditValue;
        uint256 goldValue;
    }

    // Storage
    mapping(AssetType => AssetData) public assets;
    BasketValue public currentBasket;

    // Historical data
    mapping(uint256 => BasketValue) public historicalBaskets;
    uint256 public basketCount;

    // Configuration
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public minUpdateInterval = 1 hours;
    uint256 public maxPriceDeviation = 1000; // 10% in basis points

    // Events
    event AssetUpdated(
        AssetType indexed assetType,
        uint256 price,
        DataSource source,
        uint256 timestamp
    );

    event BasketRecalculated(
        uint256 indexed basketId,
        uint256 totalValue,
        uint256 timestamp
    );

    event WeightUpdated(
        AssetType indexed assetType,
        uint256 oldWeight,
        uint256 newWeight
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        // Initialize asset weights
        assets[AssetType.US_TREASURIES] = AssetData({
            price: 0,
            timestamp: 0,
            weight: 3000,  // 30%
            source: DataSource.BLOOMBERG,
            isActive: true,
            lastUpdate: 0
        });

        assets[AssetType.PRIVATE_CREDIT] = AssetData({
            price: 0,
            timestamp: 0,
            weight: 2000,  // 20%
            source: DataSource.ASSET_MANAGER,
            isActive: true,
            lastUpdate: 0
        });

        assets[AssetType.GOLD] = AssetData({
            price: 0,
            timestamp: 0,
            weight: 5000,  // 50%
            source: DataSource.LBMA,
            isActive: true,
            lastUpdate: 0
        });
    }

    /**
     * @notice Update asset price from oracle
     * @param assetType The type of asset to update
     * @param price New price in USD (18 decimals)
     */
    function updateAssetPrice(
        AssetType assetType,
        uint256 price
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
        require(price > 0, "Invalid price");

        AssetData storage asset = assets[assetType];
        require(asset.isActive, "Asset not active");
        require(
            block.timestamp >= asset.timestamp + minUpdateInterval,
            "Update too frequent"
        );

        // Check price deviation
        if (asset.price > 0) {
            uint256 deviation = _calculateDeviation(asset.price, price);
            require(
                deviation <= maxPriceDeviation,
                "Price deviation too high"
            );
        }

        asset.price = price;
        asset.timestamp = block.timestamp;
        asset.lastUpdate = block.number;

        emit AssetUpdated(assetType, price, asset.source, block.timestamp);

        // Auto-recalculate basket
        _recalculateBasket();
    }

    /**
     * @notice Recalculate basket value
     * @dev Internal function called after asset updates
     */
    function _recalculateBasket() internal {
        require(
            assets[AssetType.US_TREASURIES].price > 0 &&
            assets[AssetType.PRIVATE_CREDIT].price > 0 &&
            assets[AssetType.GOLD].price > 0,
            "Not all assets have prices"
        );

        uint256 usTreasuriesValue = (assets[AssetType.US_TREASURIES].price *
                                      assets[AssetType.US_TREASURIES].weight) / BASIS_POINTS;
        uint256 privateCreditValue = (assets[AssetType.PRIVATE_CREDIT].price *
                                       assets[AssetType.PRIVATE_CREDIT].weight) / BASIS_POINTS;
        uint256 goldValue = (assets[AssetType.GOLD].price *
                             assets[AssetType.GOLD].weight) / BASIS_POINTS;

        uint256 totalValue = usTreasuriesValue + privateCreditValue + goldValue;

        currentBasket = BasketValue({
            totalValue: totalValue,
            timestamp: block.timestamp,
            usTreasuriesValue: usTreasuriesValue,
            privateCreditValue: privateCreditValue,
            goldValue: goldValue
        });

        // Store historical data
        historicalBaskets[basketCount] = currentBasket;

        emit BasketRecalculated(basketCount, totalValue, block.timestamp);
        basketCount++;
    }

    /**
     * @notice Get current basket value
     * @return Total basket value in USD
     */
    function getBasketValue() external view returns (uint256) {
        return currentBasket.totalValue;
    }

    /**
     * @notice Get asset breakdown
     */
    function getAssetBreakdown() external view returns (
        uint256 usTreasuries,
        uint256 privateCredit,
        uint256 gold,
        uint256 total
    ) {
        return (
            currentBasket.usTreasuriesValue,
            currentBasket.privateCreditValue,
            currentBasket.goldValue,
            currentBasket.totalValue
        );
    }

    /**
     * @notice Update asset weight
     * @param assetType Asset to update
     * @param newWeight New weight in basis points
     */
    function updateAssetWeight(
        AssetType assetType,
        uint256 newWeight
    ) external onlyRole(MANAGER_ROLE) {
        require(newWeight <= BASIS_POINTS, "Invalid weight");

        uint256 oldWeight = assets[assetType].weight;
        assets[assetType].weight = newWeight;

        // Verify total weights = 100%
        uint256 totalWeight = assets[AssetType.US_TREASURIES].weight +
                             assets[AssetType.PRIVATE_CREDIT].weight +
                             assets[AssetType.GOLD].weight;
        require(totalWeight == BASIS_POINTS, "Weights must sum to 100%");

        emit WeightUpdated(assetType, oldWeight, newWeight);

        if (currentBasket.totalValue > 0) {
            _recalculateBasket();
        }
    }

    /**
     * @notice Calculate price deviation
     */
    function _calculateDeviation(
        uint256 oldPrice,
        uint256 newPrice
    ) internal pure returns (uint256) {
        if (newPrice >= oldPrice) {
            return ((newPrice - oldPrice) * BASIS_POINTS) / oldPrice;
        } else {
            return ((oldPrice - newPrice) * BASIS_POINTS) / oldPrice;
        }
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @notice Grant oracle role
     */
    function addOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ORACLE_ROLE, oracle);
    }

    /**
     * @notice Revoke oracle role
     */
    function removeOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ORACLE_ROLE, oracle);
    }
}
