// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ILiquidityPool
/// @notice Interface for the LiquidityPool contract
interface ILiquidityPool {
    /// @notice Thrown when an invalid amount is provided
    error InvalidAmount();

    /// @notice Thrown when an unauthorized address attempts an operation
    error Unauthorized();

    /// @notice Thrown when an invalid fee is set
    error InvalidFee();

    /// @notice Thrown when a strategy operation fails
    error StrategyFailed();

    /// @notice Thrown when an approval fails
    error ApprovalFailed();

    /// @notice Thrown when LST minting is not set up
    error LSTMintingNotSet();

    /// @notice Thrown when an invalid EigenLayer strategy is provided
    error InvalidEigenLayerStrategy();

    /// @notice Thrown when minting fails
    error MintFailed();

    /// @notice Thrown when a transfer fails
    error TransferFailed(address to);

    /// @notice Thrown when an invalid strategy is provided
    error InvalidStrategy();

    /// @notice Emitted when liquidity is added to the pool
    /// @param amount The amount of ETH added
    /// @param shares The number of shares minted
    /// @param totalAssets The total assets after adding liquidity
    /// @param totalShares The total shares after adding liquidity
    event AddLiquidity(uint256 amount, uint256 shares, uint256 totalAssets, uint256 totalShares);

    /// @notice Emitted when protocol rewards are calculated
    /// @param amount The amount of rewards
    event RewardsProtocol(uint256 amount);

    /// @notice Emitted when the protocol fee is updated
    /// @param newFee The new fee value
    /// @param updatedBy The address that updated the fee
    event ProtocolFeeUpdated(uint256 newFee, address updatedBy);

    /// @notice Adds liquidity to the pool
    function addLiquidity() external payable;

    /// @notice Processes liquidity in the pool
    function processLiquidity() external payable;

    /// @notice Gets the current exchange rate of shares to ETH
    /// @return The current rate
    function getRate() external view returns (uint256);

    /// @notice Determines which strategy to use
    event StrategySet(uint8 newStrategy);
}
