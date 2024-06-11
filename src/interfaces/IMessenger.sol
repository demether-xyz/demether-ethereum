// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMessenger {
    error InvalidAddress();
    error InvalidContract();
    error Unauthorized();
    error BridgeNotSupported();
    error FeeInsufficient();

    event SyncTokens(
        uint32 indexed chainId,
        uint8 bridgeId,
        uint256 amount,
        uint256 slippage
    );

    struct Settings {
        uint8 bridgeId;
        address router;
        uint32 bridgeChainId;
        address toAddress;
        uint256 minFee;
        uint256 maxSlippage;
    }

    function syncTokens(
        uint32 chainId,
        uint256 amount,
        address refund
    ) external payable;
}
