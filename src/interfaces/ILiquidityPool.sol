// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILiquidityPool {
    error InvalidAmount();
    error InvalidAddress();
    error StrategyNotSet();
    error Unauthorized();
    error InvalidFee();
    event AddLiquidity(uint256 amount, uint256 shares, uint256 totalAmount, uint256 totalShares);
    function addLiquidity() external payable;
    function getRate() external view returns (uint256);
}
