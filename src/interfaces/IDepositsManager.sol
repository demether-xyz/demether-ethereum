// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositsManager {
    error InvalidAddress();
    error InvalidSyncAmount();
    error InvalidParametersLength();
    error InsufficientFee();
    error Unauthorized();
    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut);
    function onMessageReceived(uint32 chainId, bytes calldata message) external;
}
