// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

/// @title Interface for Demether Open Fungible Token (DOFT)
/// @dev Extends IERC20 and IOFT for ERC-20 functionality and cross-chain capabilities.
interface IDOFT is IERC20, IOFT {
    /// @notice Mints tokens and assigns them to an address, increasing the total supply.
    /// @param _to The address that will receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    /// @return bool True if the operation was successful.
    function mint(address _to, uint256 _amount) external returns (bool);

    /// @notice Burns tokens from a specified address, reducing the total supply.
    /// @param _from The address from which tokens will be burned.
    /// @param _amount The amount of tokens to burn.
    /// @return bool True if the operation was successful.
    function burn(address _from, uint256 _amount) external returns (bool);
}
