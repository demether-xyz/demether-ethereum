// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositsManager {
    error InvalidAddress();
    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut);
}
