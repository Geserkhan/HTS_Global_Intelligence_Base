# Cross-Chain RWA Bridge - Smart Contract Specifications

## Overview

This document provides detailed smart contract specifications for the Cross-Chain RWA Bridge system, covering both Chain A (Ethereum) and Chain B (Polygon) implementations.

---

## Chain A: Ethereum Smart Contracts

### 1. RWABridgeEthereum.sol

Main bridge contract on Ethereum responsible for locking RWA tokens and initiating cross-chain transfers.

#### Contract Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

interface IRWABridgeEthereum {

    // ========== STRUCTS ==========

    struct BridgeRequest {
        address tokenContract;
        uint256 tokenId;
        address sender;
        address recipient;
        uint256 timestamp;
        BridgeStatus status;
        bytes32 complianceHash;
    }

    enum BridgeStatus {
        Pending,
        Locked,
        Completed,
        Failed,
        Cancelled
    }

    enum TokenType {
        ERC721,
        ERC1155
    }

    // ========== EVENTS ==========

    event TokensLocked(
        bytes32 indexed requestId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address sender,
        address recipient,
        uint256 amount,
        TokenType tokenType
    );

    event BridgeRequestInitiated(
        bytes32 indexed requestId,
        address indexed sender,
        string destinationChain,
        bytes32 complianceHash
    );

    event BridgeRequestCompleted(
        bytes32 indexed requestId,
        uint256 timestamp
    );

    event TokensUnlocked(
        bytes32 indexed requestId,
        address indexed recipient,
        uint256 indexed tokenId
    );

    event ComplianceVerified(
        bytes32 indexed requestId,
        address indexed user,
        bool approved
    );

    event EmergencyWithdrawal(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient
    );

    // ========== FUNCTIONS ==========

    /**
     * @notice Initialize bridge transfer for ERC721 token
     * @param tokenContract Address of the RWA token contract
     * @param tokenId ID of the token to bridge
     * @param recipient Address on destination chain
     * @param destinationChain Axelar chain identifier
     * @param complianceProof KYC/AML verification proof
     */
    function bridgeERC721(
        address tokenContract,
        uint256 tokenId,
        address recipient,
        string calldata destinationChain,
        bytes calldata complianceProof
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Initialize bridge transfer for ERC1155 token
     * @param tokenContract Address of the RWA token contract
     * @param tokenId ID of the token to bridge
     * @param amount Amount of tokens to bridge
     * @param recipient Address on destination chain
     * @param destinationChain Axelar chain identifier
     * @param complianceProof KYC/AML verification proof
     */
    function bridgeERC1155(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address recipient,
        string calldata destinationChain,
        bytes calldata complianceProof
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Return tokens to original owner (reverse bridge)
     * @param requestId Bridge request identifier
     */
    function unlockTokens(bytes32 requestId) external;

    /**
     * @notice Verify compliance for bridge request
     * @param requestId Bridge request identifier
     * @param approved Compliance verification result
     */
    function verifyCompliance(bytes32 requestId, bool approved) external;

    /**
     * @notice Get bridge request details
     * @param requestId Bridge request identifier
     */
    function getBridgeRequest(bytes32 requestId)
        external
        view
        returns (BridgeRequest memory);

    /**
     * @notice Emergency pause bridge operations
     */
    function pause() external;

    /**
     * @notice Resume bridge operations
     */
    function unpause() external;

    /**
     * @notice Emergency withdrawal function (admin only)
     * @param tokenContract Address of token contract
     * @param tokenId ID of token to withdraw
     * @param recipient Address to receive token
     */
    function emergencyWithdraw(
        address tokenContract,
        uint256 tokenId,
        address recipient
    ) external;
}
```

#### Key Functions Explained

##### 1. Token Locking Mechanism

```solidity
function _lockERC721(
    address tokenContract,
    uint256 tokenId,
    address sender
) internal {
    IERC721(tokenContract).transferFrom(sender, address(this), tokenId);

    // Emit event for bridge monitoring
    emit TokensLocked(
        requestId,
        tokenContract,
        tokenId,
        sender,
        recipient,
        1, // amount always 1 for ERC721
        TokenType.ERC721
    );
}
```

##### 2. Cross-Chain Message Construction

```solidity
function _sendCrossChainMessage(
    bytes32 requestId,
    address tokenContract,
    uint256 tokenId,
    address recipient,
    string calldata destinationChain,
    bytes32 metadataURI
) internal {
    bytes memory payload = abi.encode(
        requestId,
        tokenContract,
        tokenId,
        recipient,
        metadataURI,
        block.timestamp
    );

    // Pay for gas on destination chain
    gasService.payNativeGasForContractCall{value: msg.value}(
        address(this),
        destinationChain,
        destinationAddress,
        payload,
        msg.sender
    );

    // Send message via Axelar Gateway
    gateway.callContract(destinationChain, destinationAddress, payload);
}
```

##### 3. Compliance Integration

```solidity
function _checkCompliance(
    address user,
    bytes calldata complianceProof
) internal view returns (bool) {
    // Query compliance oracle
    (bool isVerified, uint256 verificationTime) =
        complianceOracle.verifyUser(user, complianceProof);

    // Check verification is recent (within 24 hours)
    require(
        block.timestamp - verificationTime < 24 hours,
        "Compliance verification expired"
    );

    return isVerified;
}
```

#### Access Control Roles

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```

- **ADMIN_ROLE**: Configure bridge parameters, manage roles
- **COMPLIANCE_ROLE**: Verify KYC/AML compliance
- **OPERATOR_ROLE**: Process bridge requests, manage validators
- **EMERGENCY_ROLE**: Execute emergency functions (pause, withdraw)

### 2. RWAToken.sol (Example Implementation)

Standard RWA token contract compatible with bridge.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RWAToken is ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIdCounter;

    // Asset metadata
    struct AssetMetadata {
        string assetType; // "real_estate", "art", "commodity", etc.
        string jurisdiction;
        string legalDocumentURI;
        uint256 valuationUSD;
        uint256 lastValuationDate;
    }

    mapping(uint256 => AssetMetadata) public assetMetadata;

    constructor() ERC721("RWA Token", "RWA") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mintRWA(
        address to,
        string memory metadataURI,
        AssetMetadata memory metadata
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, metadataURI);
        assetMetadata[tokenId] = metadata;
        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## Chain B: Polygon Smart Contracts

### 1. RWABridgePolygon.sol

Main bridge contract on Polygon responsible for minting wrapped tokens and managing liquidity.

#### Contract Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWABridgePolygon {

    // ========== STRUCTS ==========

    struct WrappedToken {
        address originalContract;
        string originalChain;
        uint256 originalTokenId;
        address wrappedContract;
        uint256 wrappedTokenId;
        uint256 mintTime;
    }

    // ========== EVENTS ==========

    event TokensMinted(
        bytes32 indexed requestId,
        address indexed wrappedContract,
        uint256 indexed tokenId,
        address recipient,
        string originalChain
    );

    event TokensBurned(
        bytes32 indexed requestId,
        address indexed wrappedContract,
        uint256 indexed tokenId,
        address sender
    );

    event WrappedContractDeployed(
        address indexed originalContract,
        address indexed wrappedContract,
        string originalChain
    );

    event BridgeMessageReceived(
        bytes32 indexed requestId,
        string sourceChain,
        address sourceAddress
    );

    // ========== FUNCTIONS ==========

    /**
     * @notice Receive cross-chain message from Axelar Gateway
     * @param sourceChain Source blockchain identifier
     * @param sourceAddress Source contract address
     * @param payload Encoded bridge request data
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external;

    /**
     * @notice Burn wrapped tokens and initiate reverse bridge
     * @param wrappedContract Address of wrapped token contract
     * @param tokenId ID of wrapped token
     * @param recipient Address on source chain
     */
    function burnAndBridge(
        address wrappedContract,
        uint256 tokenId,
        address recipient
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Get wrapped token details
     * @param wrappedContract Address of wrapped contract
     * @param tokenId Wrapped token ID
     */
    function getWrappedToken(address wrappedContract, uint256 tokenId)
        external
        view
        returns (WrappedToken memory);

    /**
     * @notice Deploy new wrapped token contract
     * @param originalContract Address of original token on source chain
     * @param originalChain Source blockchain identifier
     * @param name Token name
     * @param symbol Token symbol
     */
    function deployWrappedContract(
        address originalContract,
        string calldata originalChain,
        string calldata name,
        string calldata symbol
    ) external returns (address wrappedContract);
}
```

#### Key Functions Explained

##### 1. Receiving Cross-Chain Messages

```solidity
function _execute(
    string calldata sourceChain,
    string calldata sourceAddress,
    bytes calldata payload
) external override {
    // Verify message from Axelar Gateway
    require(
        msg.sender == address(gateway),
        "Only Axelar Gateway can call"
    );

    // Decode payload
    (
        bytes32 requestId,
        address originalContract,
        uint256 originalTokenId,
        address recipient,
        bytes32 metadataURI,
        uint256 timestamp
    ) = abi.decode(payload, (bytes32, address, uint256, address, bytes32, uint256));

    // Verify compliance on destination chain
    require(
        _checkRecipientCompliance(recipient),
        "Recipient not compliant"
    );

    // Mint wrapped token
    _mintWrappedToken(
        requestId,
        originalContract,
        originalTokenId,
        recipient,
        sourceChain,
        metadataURI
    );
}
```

##### 2. Minting Wrapped Tokens

```solidity
function _mintWrappedToken(
    bytes32 requestId,
    address originalContract,
    uint256 originalTokenId,
    address recipient,
    string memory sourceChain,
    bytes32 metadataURI
) internal {
    // Get or deploy wrapped contract
    address wrappedContract = wrappedContracts[originalContract][sourceChain];

    if (wrappedContract == address(0)) {
        wrappedContract = _deployWrappedContract(
            originalContract,
            sourceChain
        );
    }

    // Mint wrapped token
    uint256 wrappedTokenId = IWrappedRWA(wrappedContract).mint(
        recipient,
        originalTokenId,
        metadataURI
    );

    // Store mapping
    wrappedTokens[requestId] = WrappedToken({
        originalContract: originalContract,
        originalChain: sourceChain,
        originalTokenId: originalTokenId,
        wrappedContract: wrappedContract,
        wrappedTokenId: wrappedTokenId,
        mintTime: block.timestamp
    });

    emit TokensMinted(
        requestId,
        wrappedContract,
        wrappedTokenId,
        recipient,
        sourceChain
    );
}
```

##### 3. Reverse Bridge (Burn and Unlock)

```solidity
function burnAndBridge(
    address wrappedContract,
    uint256 tokenId,
    address recipient
) external payable returns (bytes32 requestId) {
    // Verify ownership
    require(
        IWrappedRWA(wrappedContract).ownerOf(tokenId) == msg.sender,
        "Not token owner"
    );

    // Get original token details
    WrappedToken memory wrapped = _getWrappedTokenByWrappedId(
        wrappedContract,
        tokenId
    );

    // Burn wrapped token
    IWrappedRWA(wrappedContract).burn(tokenId);

    // Generate request ID
    requestId = keccak256(
        abi.encodePacked(
            wrapped.originalContract,
            wrapped.originalTokenId,
            msg.sender,
            block.timestamp
        )
    );

    // Send unlock message to source chain
    _sendUnlockMessage(
        requestId,
        wrapped.originalContract,
        wrapped.originalTokenId,
        recipient,
        wrapped.originalChain
    );

    emit TokensBurned(requestId, wrappedContract, tokenId, msg.sender);
}
```

### 2. WrappedRWA.sol

Wrapped token contract for RWA assets bridged to Polygon.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract WrappedRWA is ERC721URIStorage, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    address public immutable originalContract;
    string public immutable originalChain;

    // Mapping from wrapped token ID to original token ID
    mapping(uint256 => uint256) public originalTokenIds;

    constructor(
        address _originalContract,
        string memory _originalChain,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        originalContract = _originalContract;
        originalChain = _originalChain;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ROLE, msg.sender);
    }

    function mint(
        address to,
        uint256 originalTokenId,
        bytes32 metadataURI
    ) external onlyRole(BRIDGE_ROLE) returns (uint256) {
        uint256 wrappedTokenId = uint256(
            keccak256(abi.encodePacked(originalTokenId, originalChain))
        );

        _safeMint(to, wrappedTokenId);
        _setTokenURI(wrappedTokenId, string(abi.encodePacked(metadataURI)));
        originalTokenIds[wrappedTokenId] = originalTokenId;

        return wrappedTokenId;
    }

    function burn(uint256 tokenId) external onlyRole(BRIDGE_ROLE) {
        _burn(tokenId);
        delete originalTokenIds[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## Compliance Oracle Contract

### ComplianceOracle.sol

Provides KYC/AML verification services for bridge operations.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ComplianceOracle is ChainlinkClient, AccessControl {
    using Chainlink for Chainlink.Request;

    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    struct ComplianceRecord {
        bool isVerified;
        uint256 verificationTime;
        string jurisdiction;
        uint256 riskScore; // 0-100, lower is better
    }

    mapping(address => ComplianceRecord) public complianceRecords;

    event ComplianceUpdated(
        address indexed user,
        bool isVerified,
        string jurisdiction,
        uint256 riskScore
    );

    function updateCompliance(
        address user,
        bool isVerified,
        string memory jurisdiction,
        uint256 riskScore
    ) external onlyRole(VERIFIER_ROLE) {
        complianceRecords[user] = ComplianceRecord({
            isVerified: isVerified,
            verificationTime: block.timestamp,
            jurisdiction: jurisdiction,
            riskScore: riskScore
        });

        emit ComplianceUpdated(user, isVerified, jurisdiction, riskScore);
    }

    function verifyUser(address user, bytes calldata proof)
        external
        view
        returns (bool isVerified, uint256 verificationTime)
    {
        ComplianceRecord memory record = complianceRecords[user];

        // Check verification is recent (within 30 days)
        if (block.timestamp - record.verificationTime > 30 days) {
            return (false, 0);
        }

        // Check risk score threshold
        if (record.riskScore > 70) {
            return (false, record.verificationTime);
        }

        return (record.isVerified, record.verificationTime);
    }

    function isCompliant(address user) external view returns (bool) {
        ComplianceRecord memory record = complianceRecords[user];
        return record.isVerified &&
               block.timestamp - record.verificationTime <= 30 days &&
               record.riskScore <= 70;
    }
}
```

---

## Gas Optimization Strategies

### 1. Batch Operations

```solidity
function bridgeMultipleERC721(
    address[] calldata tokenContracts,
    uint256[] calldata tokenIds,
    address recipient,
    string calldata destinationChain,
    bytes calldata complianceProof
) external payable returns (bytes32[] memory requestIds) {
    require(tokenContracts.length == tokenIds.length, "Array length mismatch");
    require(tokenContracts.length <= 20, "Batch size too large");

    requestIds = new bytes32[](tokenContracts.length);

    for (uint256 i = 0; i < tokenContracts.length; i++) {
        requestIds[i] = _processSingleBridge(
            tokenContracts[i],
            tokenIds[i],
            recipient,
            destinationChain,
            complianceProof
        );
    }

    // Send single cross-chain message for all tokens
    _sendBatchCrossChainMessage(requestIds, destinationChain);
}
```

### 2. Efficient Storage Patterns

```solidity
// Pack related data into single storage slot
struct PackedBridgeData {
    uint96 timestamp;        // 96 bits - enough until year 2^96
    uint96 amount;          // 96 bits - sufficient for most amounts
    uint64 status;          // 64 bits - enum storage
}

// Use mappings instead of arrays for large datasets
mapping(bytes32 => PackedBridgeData) private bridgeData;
```

### 3. Event-Driven Architecture

```solidity
// Minimize on-chain storage, use events for historical data
event DetailedBridgeRecord(
    bytes32 indexed requestId,
    address indexed tokenContract,
    uint256 tokenId,
    address sender,
    address recipient,
    string destinationChain,
    bytes32 metadataURI,
    uint256 timestamp,
    bytes complianceProof
);
```

---

## Security Considerations

### 1. Reentrancy Protection

All external token transfers use OpenZeppelin's `ReentrancyGuard`:

```solidity
function bridgeERC721(...) external payable nonReentrant returns (bytes32) {
    // Function implementation
}
```

### 2. Access Control

Multi-layer access control using OpenZeppelin's `AccessControl`:

```solidity
modifier onlyCompliantUser(address user) {
    require(
        hasRole(COMPLIANCE_ROLE, msg.sender) ||
        complianceOracle.isCompliant(user),
        "User not compliant"
    );
    _;
}
```

### 3. Emergency Mechanisms

```solidity
function pause() external onlyRole(EMERGENCY_ROLE) {
    _pause();
}

function emergencyWithdraw(
    address tokenContract,
    uint256 tokenId,
    address recipient
) external onlyRole(EMERGENCY_ROLE) whenPaused {
    require(
        block.timestamp > lastEmergencyAction + 48 hours,
        "Emergency cooldown active"
    );

    IERC721(tokenContract).transferFrom(address(this), recipient, tokenId);
    lastEmergencyAction = block.timestamp;

    emit EmergencyWithdrawal(tokenContract, tokenId, recipient);
}
```

---

## Testing Requirements

### Unit Tests
- Token locking/unlocking mechanisms
- Compliance verification logic
- Access control permissions
- Gas optimization verification

### Integration Tests
- Axelar Gateway interaction
- Cross-chain message passing
- Wrapped token deployment
- End-to-end bridge flow

### Security Tests
- Reentrancy attack prevention
- Front-running mitigation
- Authorization bypass attempts
- Emergency function abuse prevention

### Fuzz Testing
- Random input validation
- Edge case handling
- Gas limit scenarios
- Timestamp manipulation resistance

---

**Document Version**: 1.0
**Last Updated**: 2025-11-18
**Solidity Version**: ^0.8.20
**Dependencies**:
- OpenZeppelin Contracts v5.0+
- Axelar GMP SDK v3.0+
- Chainlink Contracts v0.8+
