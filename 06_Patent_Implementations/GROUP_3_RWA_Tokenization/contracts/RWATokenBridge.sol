// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RWATokenBridge
 * @notice Cross-chain RWA bridge with compliance and verification
 * @dev Bridges real-world assets between chains with KYC/AML checks
 */
contract RWATokenBridge is ReentrancyGuard {

    struct RWAToken {
        address tokenAddress;
        string assetType;          // "real_estate", "commodity", "security"
        bytes32 assetId;           // Unique real-world asset ID
        uint256 totalSupply;
        bool isVerified;
        address custodian;
        uint256 lastAuditDate;
    }

    struct BridgeRequest {
        uint256 requestId;
        address user;
        address tokenAddress;
        uint256 amount;
        uint256 sourceChainId;
        uint256 destChainId;
        BridgeStatus status;
        bool kycPassed;
        bool amlPassed;
        uint256 requestedAt;
    }

    struct ComplianceCheck {
        address user;
        bool kycVerified;
        bool amlVerified;
        uint256 verifiedAt;
        uint256 expiryDate;
        bytes32 verificationHash;
    }

    enum BridgeStatus { Pending, Approved, Rejected, Completed }

    mapping(address => RWAToken) public rwaTokens;
    mapping(uint256 => BridgeRequest) public bridgeRequests;
    mapping(address => ComplianceCheck) public complianceChecks;
    mapping(bytes32 => bool) public processedTransfers;

    uint256 public requestCounter;
    address public complianceOracle;
    address public admin;

    event RWATokenRegistered(address indexed token, string assetType, bytes32 assetId);
    event BridgeRequested(uint256 indexed requestId, address user, uint256 amount, uint256 destChain);
    event ComplianceVerified(address indexed user, bool kyc, bool aml);
    event TokensBridged(uint256 indexed requestId, address user, uint256 amount, uint256 destChain);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyCompliant(address user) {
        ComplianceCheck memory check = complianceChecks[user];
        require(check.kycVerified && check.amlVerified, "Not compliant");
        require(block.timestamp < check.expiryDate, "Compliance expired");
        _;
    }

    constructor(address _complianceOracle) {
        admin = msg.sender;
        complianceOracle = _complianceOracle;
    }

    function registerRWAToken(
        address tokenAddress,
        string calldata assetType,
        bytes32 assetId,
        address custodian
    ) external onlyAdmin {
        rwaTokens[tokenAddress] = RWAToken({
            tokenAddress: tokenAddress,
            assetType: assetType,
            assetId: assetId,
            totalSupply: IERC20(tokenAddress).totalSupply(),
            isVerified: true,
            custodian: custodian,
            lastAuditDate: block.timestamp
        });

        emit RWATokenRegistered(tokenAddress, assetType, assetId);
    }

    function updateCompliance(
        address user,
        bool kycVerified,
        bool amlVerified,
        uint256 expiryDate,
        bytes32 verificationHash
    ) external {
        require(msg.sender == complianceOracle, "Only compliance oracle");

        complianceChecks[user] = ComplianceCheck({
            user: user,
            kycVerified: kycVerified,
            amlVerified: amlVerified,
            verifiedAt: block.timestamp,
            expiryDate: expiryDate,
            verificationHash: verificationHash
        });

        emit ComplianceVerified(user, kycVerified, amlVerified);
    }

    function requestBridge(
        address tokenAddress,
        uint256 amount,
        uint256 destChainId
    ) external onlyCompliant(msg.sender) nonReentrant returns (uint256 requestId) {
        require(rwaTokens[tokenAddress].isVerified, "Token not verified");
        require(amount > 0, "Invalid amount");

        // Lock tokens
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        requestId = ++requestCounter;
        bridgeRequests[requestId] = BridgeRequest({
            requestId: requestId,
            user: msg.sender,
            tokenAddress: tokenAddress,
            amount: amount,
            sourceChainId: block.chainid,
            destChainId: destChainId,
            status: BridgeStatus.Pending,
            kycPassed: true,
            amlPassed: true,
            requestedAt: block.timestamp
        });

        emit BridgeRequested(requestId, msg.sender, amount, destChainId);
    }

    function completeBridge(
        uint256 requestId,
        bytes32 transferHash
    ) external onlyAdmin nonReentrant {
        BridgeRequest storage request = bridgeRequests[requestId];
        require(request.status == BridgeStatus.Pending, "Invalid status");
        require(!processedTransfers[transferHash], "Already processed");

        request.status = BridgeStatus.Completed;
        processedTransfers[transferHash] = true;

        emit TokensBridged(requestId, request.user, request.amount, request.destChainId);
    }

    function unlockTokens(
        address user,
        address tokenAddress,
        uint256 amount,
        bytes32 sourceTransferHash
    ) external onlyAdmin onlyCompliant(user) nonReentrant {
        require(!processedTransfers[sourceTransferHash], "Already processed");
        require(rwaTokens[tokenAddress].isVerified, "Token not verified");

        processedTransfers[sourceTransferHash] = true;
        IERC20(tokenAddress).transfer(user, amount);
    }
}
