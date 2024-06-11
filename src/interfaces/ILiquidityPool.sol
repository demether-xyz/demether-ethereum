// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILiquidityPool {
    function addLiquidity() external payable;
    function getRate() external view returns (uint256);
}
