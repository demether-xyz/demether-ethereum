// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILiquidityPool {
    error InvalidAmount();
    error InvalidAddress();
    error Unauthorized();
    error InvalidFee();
    error TransferFailed(address);
    error StrategyFailed();
    error ApprovalFailed();
    error LSTMintingNotSet();
    error InvalidEigenLayerStrategy();

    event AddLiquidity(uint256 amount, uint256 shares, uint256 totalAssets, uint256 totalShares);
    event RewardsProtocol(uint256 amount);

    function addLiquidity() external payable;
    function getRate() external view returns (uint256);
}
