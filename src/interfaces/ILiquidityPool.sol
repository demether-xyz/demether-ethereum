// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILiquidityPool {
    error InvalidAmount();
    error Unauthorized();
    error InvalidFee();
    error StrategyFailed();
    error ApprovalFailed();
    error LSTMintingNotSet();
    error InvalidEigenLayerStrategy();
    error MintFailed();

    event AddLiquidity(uint256 amount, uint256 shares, uint256 totalAssets, uint256 totalShares);
    event RewardsProtocol(uint256 amount);
    event ProtocolFeeUpdated(uint256 newFee, address updatedBy);

    function addLiquidity(bool) external payable;
    function getRate() external view returns (uint256);
}
