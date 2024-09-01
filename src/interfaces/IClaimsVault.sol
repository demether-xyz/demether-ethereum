// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

/// @title IClaimsVault Interface for Demether Finance
/// @dev Defines the external functions for the ClaimsVault contract
/// @notice Interface for interacting with the ClaimsVault contract
interface IClaimsVault {
    /// @notice Returns the address of the LiquidityPool contract
    /// @return The address of the LiquidityPool
    function pool() external view returns (address);

    /// @notice Allows LiquidityPool to claim any ETH received
    /// @dev Can only be called by the LiquidityPool
    function claimFunds() external;

    /// @notice Indicates an invalid address was provided
    error InvalidAddress();

    /// @notice Indicates the caller is not authorized to perform an action
    error Unauthorized();

    /// @notice Indicates a transfer of funds failed
    error TransferFailed();
}
