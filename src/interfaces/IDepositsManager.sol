// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositsManager {
    error InvalidAddress();
    error InvalidSyncAmount();
    error InvalidParametersLength();
    error InsufficientFee();
    error Unauthorized();
    error InvalidMessageCode();
    error RateInvalid(uint256);
    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut);
    event DepositFeeSet(uint256 fee);
    function onMessageReceived(uint32 chainId, bytes calldata message) external;
    function getRate() external view returns (uint256);
}
