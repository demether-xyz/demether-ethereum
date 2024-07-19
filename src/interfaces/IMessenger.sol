// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMessenger {
    error InvalidAddress();
    error InvalidContract();
    error Unauthorized();
    error BridgeNotSupported();
    error InsufficientFee();
    error InvalidParametersLength();
    error OnlyEndpoint(address);
    error OnlyPeer(uint32, address);

    event SyncTokens(uint32 indexed chainId, uint8 bridgeId, uint256 amount, uint256 slippage);

    struct Settings {
        // local info
        uint8 bridgeId;
        // destination info
        uint32 chainId;
        uint32 bridgeChainId;
        address toAddress;
        // settings
        uint256 minFee;
        uint256 maxSlippage;
        bytes options;
    }

    function syncTokens(uint32 chainId, uint256 amount, address refund) external payable;

    function syncMessage(uint32 chainId, bytes calldata data, address refund) external payable;

    function getMessageSettings(uint32 chainId) external view returns (Settings memory);

    event SettingsTokens(uint32 indexed chainId, uint8 bridgeId, address toAddress);
    event SettingsMessages(uint32 indexed chainId, uint8 bridgeId, address toAddress);
}
