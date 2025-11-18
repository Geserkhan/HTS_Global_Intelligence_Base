// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RLXStablecoin
 * @notice Self-reinforcing stablecoin with contribution-based minting
 * @dev Dynamically adjusts collateral requirements based on user contribution scores
 */
contract RLXStablecoin is ERC20, ReentrancyGuard {

    struct UserProfile {
        uint256 contributionScore;     // 0-100
        uint256 totalContributions;    // USD value
        uint256 stakingDuration;       // Days
        uint256 governanceVotes;
        uint256 lastUpdateTime;
        uint256 collateralRatio;       // Personalized ratio (basis points)
    }

    struct CollateralAsset {
        address tokenAddress;
        uint256 price;                 // USD price (18 decimals)
        uint256 baseCollateralRatio;  // Base ratio for all users (basis points)
        bool isActive;
    }

    struct MintPosition {
        address user;
        address collateralToken;
        uint256 collateralAmount;
        uint256 rlxMinted;
        uint256 collateralRatio;       // Ratio at mint time
        uint256 mintedAt;
        bool isActive;
    }

    mapping(address => UserProfile) public userProfiles;
    mapping(address => CollateralAsset) public collateralAssets;
    mapping(address => mapping(uint256 => MintPosition)) public mintPositions;
    mapping(address => uint256) public positionCounter;

    address public admin;
    address public oracle;

    uint256 public constant BASE_COLLATERAL_RATIO = 15000;  // 150%
    uint256 public constant MAX_DISCOUNT = 5000;            // 50% max discount
    uint256 public constant LIQUIDATION_THRESHOLD = 12000;  // 120%
    uint256 public targetPrice = 1 ether;                   // $1 USD

    event ContributionScoreUpdated(address indexed user, uint256 newScore);
    event RLXMinted(address indexed user, uint256 amount, uint256 collateralRatio);
    event CollateralAdded(address indexed user, address token, uint256 amount);
    event PositionLiquidated(address indexed user, uint256 positionId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle || msg.sender == admin, "Only oracle");
        _;
    }

    constructor() ERC20("RLX Stablecoin", "RLX") {
        admin = msg.sender;
        oracle = msg.sender;
    }

    function registerCollateral(
        address tokenAddress,
        uint256 initialPrice,
        uint256 baseRatio
    ) external onlyAdmin {
        collateralAssets[tokenAddress] = CollateralAsset({
            tokenAddress: tokenAddress,
            price: initialPrice,
            baseCollateralRatio: baseRatio,
            isActive: true
        });
    }

    function updateContributionScore(
        address user,
        uint256 contributionValue,
        uint256 stakingDays,
        uint256 votes
    ) external onlyOracle {
        UserProfile storage profile = userProfiles[user];

        profile.totalContributions += contributionValue;
        profile.stakingDuration = stakingDays;
        profile.governanceVotes = votes;
        profile.lastUpdateTime = block.timestamp;

        // Calculate contribution score (0-100)
        uint256 score = _calculateContributionScore(
            profile.totalContributions,
            stakingDays,
            votes
        );
        profile.contributionScore = score;

        // Calculate personalized collateral ratio
        profile.collateralRatio = _calculateCollateralRatio(score);

        emit ContributionScoreUpdated(user, score);
    }

    function mintRLX(
        address collateralToken,
        uint256 collateralAmount,
        uint256 rlxAmount
    ) external nonReentrant {
        require(collateralAssets[collateralToken].isActive, "Invalid collateral");

        UserProfile memory profile = userProfiles[msg.sender];
        uint256 requiredRatio = profile.collateralRatio > 0
            ? profile.collateralRatio
            : BASE_COLLATERAL_RATIO;

        // Check collateralization
        uint256 collateralValue = _getCollateralValue(collateralToken, collateralAmount);
        uint256 requiredCollateral = (rlxAmount * requiredRatio) / 10000;
        require(collateralValue >= requiredCollateral, "Insufficient collateral");

        // Transfer collateral
        IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        // Mint RLX
        _mint(msg.sender, rlxAmount);

        // Record position
        uint256 positionId = ++positionCounter[msg.sender];
        mintPositions[msg.sender][positionId] = MintPosition({
            user: msg.sender,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            rlxMinted: rlxAmount,
            collateralRatio: requiredRatio,
            mintedAt: block.timestamp,
            isActive: true
        });

        emit RLXMinted(msg.sender, rlxAmount, requiredRatio);
    }

    function burnRLX(uint256 positionId) external nonReentrant {
        MintPosition storage position = mintPositions[msg.sender][positionId];
        require(position.isActive, "Position not active");
        require(position.user == msg.sender, "Not your position");

        // Burn RLX
        _burn(msg.sender, position.rlxMinted);

        // Return collateral
        IERC20(position.collateralToken).transfer(msg.sender, position.collateralAmount);

        position.isActive = false;
    }

    function liquidatePosition(
        address user,
        uint256 positionId
    ) external nonReentrant {
        MintPosition storage position = mintPositions[user][positionId];
        require(position.isActive, "Position not active");

        // Check if under-collateralized
        uint256 collateralValue = _getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        uint256 currentRatio = (collateralValue * 10000) / position.rlxMinted;

        require(currentRatio < LIQUIDATION_THRESHOLD, "Not liquidatable");

        // Liquidate
        _burn(address(this), position.rlxMinted);
        IERC20(position.collateralToken).transfer(msg.sender, position.collateralAmount);

        position.isActive = false;

        emit PositionLiquidated(user, positionId);
    }

    function _calculateContributionScore(
        uint256 totalContributions,
        uint256 stakingDays,
        uint256 votes
    ) internal pure returns (uint256) {
        // Score = 40% contributions + 30% staking + 30% governance
        uint256 contributionScore = (totalContributions / 1000 ether) * 40; // Cap at 40
        if (contributionScore > 40) contributionScore = 40;

        uint256 stakingScore = (stakingDays / 365) * 30;  // Cap at 30
        if (stakingScore > 30) stakingScore = 30;

        uint256 governanceScore = (votes / 100) * 30;  // Cap at 30
        if (governanceScore > 30) governanceScore = 30;

        uint256 total = contributionScore + stakingScore + governanceScore;
        return total > 100 ? 100 : total;
    }

    function _calculateCollateralRatio(uint256 contributionScore) internal pure returns (uint256) {
        // Higher score = lower collateral requirement
        // Score 0: 150% ratio
        // Score 100: 100% ratio (50% discount)
        uint256 discount = (contributionScore * MAX_DISCOUNT) / 100;
        return BASE_COLLATERAL_RATIO - discount;
    }

    function _getCollateralValue(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        CollateralAsset memory asset = collateralAssets[token];
        return (amount * asset.price) / 1 ether;
    }

    function getUserCollateralRatio(address user) external view returns (uint256) {
        UserProfile memory profile = userProfiles[user];
        return profile.collateralRatio > 0 ? profile.collateralRatio : BASE_COLLATERAL_RATIO;
    }

    function getPositionHealth(
        address user,
        uint256 positionId
    ) external view returns (uint256 healthFactor) {
        MintPosition memory position = mintPositions[user][positionId];
        if (!position.isActive) return 0;

        uint256 collateralValue = _getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        healthFactor = (collateralValue * 10000) / position.rlxMinted;
    }

    function updatePrice(address token, uint256 newPrice) external onlyOracle {
        collateralAssets[token].price = newPrice;
    }
}
