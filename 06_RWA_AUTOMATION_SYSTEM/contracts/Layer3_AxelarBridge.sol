// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AxelarBridge
 * @notice Layer 3: Axelar Cross-Chain Bridge Integration
 * @dev Enables multi-chain synchronization of RWA data and triggers
 */
contract AxelarBridge is AccessControl, ReentrancyGuard {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    // Supported chains
    enum ChainId {
        ETHEREUM,
        POLYGON,
        ARBITRUM,
        OPTIMISM,
        AVALANCHE,
        BSC
    }

    struct CrossChainMessage {
        uint256 messageId;
        ChainId sourceChain;
        ChainId destinationChain;
        bytes payload;
        uint256 timestamp;
        bool isProcessed;
        bytes32 messageHash;
    }

    struct ChainConfig {
        string chainName;
        address gatewayAddress;
        bool isActive;
        uint256 minConfirmations;
    }

    struct SyncData {
        uint256 basketValue;
        uint256 ltvRatio;
        uint256 timestamp;
        bool isVerified;
        uint256[] triggerIds;
    }

    // Storage
    mapping(uint256 => CrossChainMessage) public messages;
    mapping(ChainId => ChainConfig) public chainConfigs;
    mapping(bytes32 => bool) public processedMessages;
    mapping(ChainId => SyncData) public chainData;

    uint256 public messageCount;
    uint256 public constant MESSAGE_TTL = 1 hours;

    // Events
    event MessageSent(
        uint256 indexed messageId,
        ChainId indexed sourceChain,
        ChainId indexed destinationChain,
        bytes32 messageHash
    );

    event MessageReceived(
        uint256 indexed messageId,
        ChainId indexed sourceChain,
        bytes payload
    );

    event MessageProcessed(
        uint256 indexed messageId,
        bool success
    );

    event ChainSynced(
        ChainId indexed chainId,
        uint256 basketValue,
        uint256 ltvRatio,
        uint256 timestamp
    );

    event ChainConfigured(
        ChainId indexed chainId,
        string chainName,
        address gatewayAddress
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ROLE, msg.sender);

        // Initialize chain configurations
        _initializeChains();
    }

    /**
     * @notice Initialize supported chains
     */
    function _initializeChains() internal {
        chainConfigs[ChainId.ETHEREUM] = ChainConfig({
            chainName: "Ethereum",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 12
        });

        chainConfigs[ChainId.POLYGON] = ChainConfig({
            chainName: "Polygon",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 128
        });

        chainConfigs[ChainId.ARBITRUM] = ChainConfig({
            chainName: "Arbitrum",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 1
        });

        chainConfigs[ChainId.OPTIMISM] = ChainConfig({
            chainName: "Optimism",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 1
        });

        chainConfigs[ChainId.AVALANCHE] = ChainConfig({
            chainName: "Avalanche",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 1
        });

        chainConfigs[ChainId.BSC] = ChainConfig({
            chainName: "BSC",
            gatewayAddress: address(0),
            isActive: true,
            minConfirmations: 15
        });
    }

    /**
     * @notice Send cross-chain message
     * @param destinationChain Target chain
     * @param payload Message payload
     */
    function sendMessage(
        ChainId destinationChain,
        bytes memory payload
    ) external onlyRole(BRIDGE_ROLE) nonReentrant returns (uint256) {
        require(
            chainConfigs[destinationChain].isActive,
            "Destination chain not active"
        );

        uint256 messageId = messageCount++;
        bytes32 messageHash = keccak256(
            abi.encodePacked(messageId, destinationChain, payload, block.timestamp)
        );

        messages[messageId] = CrossChainMessage({
            messageId: messageId,
            sourceChain: ChainId.ETHEREUM, // Current chain
            destinationChain: destinationChain,
            payload: payload,
            timestamp: block.timestamp,
            isProcessed: false,
            messageHash: messageHash
        });

        emit MessageSent(
            messageId,
            ChainId.ETHEREUM,
            destinationChain,
            messageHash
        );

        return messageId;
    }

    /**
     * @notice Receive cross-chain message
     * @param sourceChain Source chain
     * @param payload Message payload
     */
    function receiveMessage(
        ChainId sourceChain,
        bytes memory payload,
        bytes32 messageHash
    ) external onlyRole(RELAYER_ROLE) nonReentrant {
        require(!processedMessages[messageHash], "Message already processed");
        require(
            chainConfigs[sourceChain].isActive,
            "Source chain not active"
        );

        uint256 messageId = messageCount++;

        messages[messageId] = CrossChainMessage({
            messageId: messageId,
            sourceChain: sourceChain,
            destinationChain: ChainId.ETHEREUM,
            payload: payload,
            timestamp: block.timestamp,
            isProcessed: false,
            messageHash: messageHash
        });

        processedMessages[messageHash] = true;

        emit MessageReceived(messageId, sourceChain, payload);

        // Auto-process
        _processMessage(messageId);
    }

    /**
     * @notice Process received message
     * @param messageId Message ID
     */
    function _processMessage(uint256 messageId) internal {
        CrossChainMessage storage message = messages[messageId];
        require(!message.isProcessed, "Already processed");

        // Decode payload and update chain data
        (
            uint256 basketValue,
            uint256 ltvRatio,
            uint256[] memory triggerIds
        ) = abi.decode(message.payload, (uint256, uint256, uint256[]));

        chainData[message.sourceChain] = SyncData({
            basketValue: basketValue,
            ltvRatio: ltvRatio,
            timestamp: block.timestamp,
            isVerified: true,
            triggerIds: triggerIds
        });

        message.isProcessed = true;

        emit MessageProcessed(messageId, true);
        emit ChainSynced(
            message.sourceChain,
            basketValue,
            ltvRatio,
            block.timestamp
        );
    }

    /**
     * @notice Sync data to target chain
     * @param destinationChain Target chain
     * @param basketValue Current basket value
     * @param ltvRatio Current LTV ratio
     * @param triggerIds Active trigger IDs
     */
    function syncToChain(
        ChainId destinationChain,
        uint256 basketValue,
        uint256 ltvRatio,
        uint256[] memory triggerIds
    ) external onlyRole(BRIDGE_ROLE) returns (uint256) {
        bytes memory payload = abi.encode(basketValue, ltvRatio, triggerIds);
        return sendMessage(destinationChain, payload);
    }

    /**
     * @notice Get chain sync data
     * @param chainId Chain ID
     */
    function getChainData(
        ChainId chainId
    ) external view returns (SyncData memory) {
        return chainData[chainId];
    }

    /**
     * @notice Update chain configuration
     * @param chainId Chain ID
     * @param gatewayAddress Gateway address
     * @param isActive Active status
     */
    function updateChainConfig(
        ChainId chainId,
        address gatewayAddress,
        bool isActive
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ChainConfig storage config = chainConfigs[chainId];
        config.gatewayAddress = gatewayAddress;
        config.isActive = isActive;

        emit ChainConfigured(chainId, config.chainName, gatewayAddress);
    }

    /**
     * @notice Verify message authenticity
     * @param messageId Message ID
     */
    function verifyMessage(
        uint256 messageId
    ) external view returns (bool) {
        CrossChainMessage memory message = messages[messageId];

        if (message.timestamp == 0) {
            return false;
        }

        if (block.timestamp > message.timestamp + MESSAGE_TTL) {
            return false;
        }

        bytes32 computedHash = keccak256(
            abi.encodePacked(
                message.messageId,
                message.destinationChain,
                message.payload,
                message.timestamp
            )
        );

        return computedHash == message.messageHash;
    }

    /**
     * @notice Add relayer
     */
    function addRelayer(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(RELAYER_ROLE, relayer);
    }

    /**
     * @notice Remove relayer
     */
    function removeRelayer(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(RELAYER_ROLE, relayer);
    }
}
