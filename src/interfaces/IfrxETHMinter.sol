// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Interface for frxETHMinter
/// @notice This interface defines the function for submitting and depositing ETH to mint frxETH and convert it to sfrxETH.
interface IfrxETHMinter {
    /// @notice Mint frxETH and deposit it to receive sfrxETH in one transaction
    /// @param recipient The address to receive the sfrxETH tokens
    /// @return shares The amount of sfrxETH received
    function submitAndDeposit(address recipient) external payable returns (uint256 shares);
}