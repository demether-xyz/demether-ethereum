// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IMessenger
/// @notice Interface for the Messenger contract, facilitating cross-chain message and token transfers
interface IMessenger {
    /// @notice Thrown when an invalid contract address is provided
    error InvalidContract();

    /// @notice Thrown when an unauthorized address attempts an operation
    error Unauthorized();

    /// @notice Thrown when an unsupported bridge is used
    error BridgeNotSupported();

    /// @notice Thrown when the provided fee is insufficient
    error InsufficientFee();

    /// @notice Thrown when parameter arrays have mismatched lengths
    error InvalidParametersLength();

    /// @notice Thrown when a non-endpoint address calls a restricted function
    /// @param caller The address that attempted the call
    error OnlyEndpoint(address caller);

    /// @notice Thrown when a non-peer address attempts to interact
    /// @param chainId The chain ID of the caller
    /// @param caller The address of the caller
    error OnlyPeer(uint32 chainId, address caller);

    /// @notice Thrown when an invalid chain ID is provided
    error InvalidChainId();

    /// @notice Thrown when a deposit fails
    /// @param sender The address attempting the deposit
    /// @param amount The amount that failed to deposit
    error DepositFailed(address sender, uint256 amount);

    /// @notice Thrown when an approval fails
    error ApprovalFailed();

    /// @notice Thrown when sending a message fails
    error SendMessageFailed();

    /// @notice Emitted when tokens are synchronized across chains
    /// @param chainId The destination chain ID
    /// @param bridgeId The ID of the bridge used
    /// @param amount The amount of tokens synchronized
    /// @param slippage The maximum slippage allowed
    event SyncTokens(uint32 indexed chainId, uint8 bridgeId, uint256 amount, uint256 slippage);

    /// @notice Settings structure for cross-chain operations
    struct Settings {
        uint8 bridgeId; // ID of the bridge protocol
        uint32 chainId; // Destination chain ID
        uint32 bridgeChainId; // Chain ID used by the bridge protocol
        address toAddress; // Recipient address on the destination chain
        uint256 minFee; // Minimum fee required for the operation
        uint256 maxSlippage; // Maximum allowed slippage
        bytes options; // Additional options for the transfer
    }

    /// @notice Synchronizes tokens across chains
    /// @param chainId The destination chain ID
    /// @param amount The amount of tokens to transfer
    /// @param refund The address to refund excess fees
    function syncTokens(uint32 chainId, uint256 amount, address refund) external payable;

    /// @notice Sends a message across chains
    /// @param chainId The destination chain ID
    /// @param data The message data to be sent
    /// @param refund The address to refund excess fees
    function syncMessage(uint32 chainId, bytes calldata data, address refund) external payable;

    /// @notice Retrieves message settings for a specific chain
    /// @param chainId The chain ID to query
    /// @return Settings struct for the specified chain
    function getMessageSettings(uint32 chainId) external view returns (Settings memory);

    /// @notice Emitted when token transfer settings are updated
    /// @param chainId The chain ID for which settings are updated
    /// @param bridgeId The ID of the bridge protocol
    /// @param toAddress The recipient address on the destination chain
    event SettingsTokens(uint32 indexed chainId, uint8 bridgeId, address toAddress);

    /// @notice Emitted when message transfer settings are updated
    /// @param chainId The chain ID for which settings are updated
    /// @param bridgeId The ID of the bridge protocol
    /// @param toAddress The recipient address on the destination chain
    event SettingsMessages(uint32 indexed chainId, uint8 bridgeId, address toAddress);
}
