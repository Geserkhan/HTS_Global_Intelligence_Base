// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TreasuryRebalancer
 * @notice Automated DAO treasury rebalancing with ESG compliance
 * @dev Manages portfolio allocation across multiple assets with constraints
 */
contract TreasuryRebalancer is ReentrancyGuard {

    struct Asset {
        address tokenAddress;
        uint256 currentBalance;
        uint256 targetAllocation;     // Basis points (10000 = 100%)
        uint256 minAllocation;
        uint256 maxAllocation;
        bool isESGCompliant;
        uint256 riskScore;             // 0-100
    }

    struct RebalanceProposal {
        uint256 proposalId;
        address[] assetsToSell;
        address[] assetsToBuy;
        uint256[] sellAmounts;
        uint256[] buyAmounts;
        uint256 proposedAt;
        uint256 executionDeadline;
        ProposalStatus status;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    struct ESGCriteria {
        uint256 minEnvironmentalScore;
        uint256 minSocialScore;
        uint256 minGovernanceScore;
        uint256 maxCarbonFootprint;
    }

    enum ProposalStatus { Pending, Approved, Rejected, Executed, Expired }

    mapping(address => Asset) public assets;
    mapping(uint256 => RebalanceProposal) public proposals;
    mapping(address => bool) public governors;

    address[] public assetList;
    ESGCriteria public esgCriteria;
    uint256 public proposalCounter;
    uint256 public rebalanceThreshold = 500;  // 5% deviation triggers rebalance
    uint256 public totalTreasuryValue;

    address public admin;
    address public executor;

    event AssetAdded(address indexed token, uint256 targetAllocation, bool esgCompliant);
    event RebalanceProposed(uint256 indexed proposalId, uint256 totalValue);
    event RebalanceExecuted(uint256 indexed proposalId, uint256 executedAt);
    event ESGCriteriaUpdated(uint256 minEnv, uint256 minSocial, uint256 minGov);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyGovernor() {
        require(governors[msg.sender], "Only governor");
        _;
    }

    constructor() {
        admin = msg.sender;
        executor = msg.sender;
        governors[msg.sender] = true;

        // Default ESG criteria
        esgCriteria = ESGCriteria({
            minEnvironmentalScore: 60,
            minSocialScore: 60,
            minGovernanceScore: 70,
            maxCarbonFootprint: 1000
        });
    }

    function addAsset(
        address tokenAddress,
        uint256 targetAllocation,
        uint256 minAllocation,
        uint256 maxAllocation,
        bool isESGCompliant,
        uint256 riskScore
    ) external onlyAdmin {
        require(targetAllocation <= 10000, "Invalid allocation");
        require(minAllocation <= targetAllocation, "Min > target");
        require(maxAllocation >= targetAllocation, "Max < target");

        assets[tokenAddress] = Asset({
            tokenAddress: tokenAddress,
            currentBalance: 0,
            targetAllocation: targetAllocation,
            minAllocation: minAllocation,
            maxAllocation: maxAllocation,
            isESGCompliant: isESGCompliant,
            riskScore: riskScore
        });

        assetList.push(tokenAddress);

        emit AssetAdded(tokenAddress, targetAllocation, isESGCompliant);
    }

    function proposeRebalance() external onlyGovernor returns (uint256 proposalId) {
        // Calculate current allocations
        _updateTreasuryValue();

        // Determine rebalancing needs
        (
            address[] memory assetsToSell,
            address[] memory assetsToBuy,
            uint256[] memory sellAmounts,
            uint256[] memory buyAmounts
        ) = _calculateRebalance();

        require(assetsToSell.length > 0 || assetsToBuy.length > 0, "No rebalance needed");

        proposalId = ++proposalCounter;
        proposals[proposalId] = RebalanceProposal({
            proposalId: proposalId,
            assetsToSell: assetsToSell,
            assetsToBuy: assetsToBuy,
            sellAmounts: sellAmounts,
            buyAmounts: buyAmounts,
            proposedAt: block.timestamp,
            executionDeadline: block.timestamp + 7 days,
            status: ProposalStatus.Pending,
            votesFor: 0,
            votesAgainst: 0
        });

        emit RebalanceProposed(proposalId, totalTreasuryValue);
    }

    function executeRebalance(uint256 proposalId) external nonReentrant {
        require(msg.sender == executor, "Only executor");
        RebalanceProposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Approved, "Not approved");
        require(block.timestamp <= proposal.executionDeadline, "Expired");

        // Execute sells
        for (uint256 i = 0; i < proposal.assetsToSell.length; i++) {
            // In production, integrate with DEX for swaps
            // For now, we just update balances
            assets[proposal.assetsToSell[i]].currentBalance -= proposal.sellAmounts[i];
        }

        // Execute buys
        for (uint256 i = 0; i < proposal.assetsToBuy.length; i++) {
            assets[proposal.assetsToBuy[i]].currentBalance += proposal.buyAmounts[i];
        }

        proposal.status = ProposalStatus.Executed;

        emit RebalanceExecuted(proposalId, block.timestamp);
    }

    function _updateTreasuryValue() internal {
        totalTreasuryValue = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            address token = assetList[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            assets[token].currentBalance = balance;
            // In production, multiply by price oracle
            totalTreasuryValue += balance;
        }
    }

    function _calculateRebalance() internal view returns (
        address[] memory assetsToSell,
        address[] memory assetsToBuy,
        uint256[] memory sellAmounts,
        uint256[] memory buyAmounts
    ) {
        // Simplified rebalancing logic
        // In production, use optimization algorithm
        uint256 sellCount = 0;
        uint256 buyCount = 0;

        // Count assets needing rebalancing
        for (uint256 i = 0; i < assetList.length; i++) {
            Asset memory asset = assets[assetList[i]];
            uint256 currentAllocation = (asset.currentBalance * 10000) / totalTreasuryValue;

            if (currentAllocation > asset.targetAllocation + rebalanceThreshold) {
                sellCount++;
            } else if (currentAllocation < asset.targetAllocation - rebalanceThreshold) {
                buyCount++;
            }
        }

        assetsToSell = new address[](sellCount);
        assetsToBuy = new address[](buyCount);
        sellAmounts = new uint256[](sellCount);
        buyAmounts = new uint256[](buyCount);

        // Populate arrays
        uint256 sellIdx = 0;
        uint256 buyIdx = 0;

        for (uint256 i = 0; i < assetList.length; i++) {
            Asset memory asset = assets[assetList[i]];
            uint256 currentAllocation = (asset.currentBalance * 10000) / totalTreasuryValue;

            if (currentAllocation > asset.targetAllocation + rebalanceThreshold) {
                assetsToSell[sellIdx] = asset.tokenAddress;
                sellAmounts[sellIdx] = ((currentAllocation - asset.targetAllocation) * totalTreasuryValue) / 10000;
                sellIdx++;
            } else if (currentAllocation < asset.targetAllocation - rebalanceThreshold) {
                assetsToBuy[buyIdx] = asset.tokenAddress;
                buyAmounts[buyIdx] = ((asset.targetAllocation - currentAllocation) * totalTreasuryValue) / 10000;
                buyIdx++;
            }
        }

        return (assetsToSell, assetsToBuy, sellAmounts, buyAmounts);
    }

    function updateESGCriteria(
        uint256 minEnv,
        uint256 minSocial,
        uint256 minGov,
        uint256 maxCarbon
    ) external onlyAdmin {
        esgCriteria = ESGCriteria({
            minEnvironmentalScore: minEnv,
            minSocialScore: minSocial,
            minGovernanceScore: minGov,
            maxCarbonFootprint: maxCarbon
        });

        emit ESGCriteriaUpdated(minEnv, minSocial, minGov);
    }

    function getTreasuryValue() external view returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            value += assets[assetList[i]].currentBalance;
        }
        return value;
    }

    function getAssetAllocation(address token) external view returns (
        uint256 current,
        uint256 target
    ) {
        Asset memory asset = assets[token];
        current = totalTreasuryValue > 0
            ? (asset.currentBalance * 10000) / totalTreasuryValue
            : 0;
        target = asset.targetAllocation;
    }
}
