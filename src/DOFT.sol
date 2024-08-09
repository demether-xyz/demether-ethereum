// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// *******************************************************
// *    ____                      _   _                  *
// *   |  _ \  ___ _ __ ___   ___| |_| |__   ___ _ __    *
// *   | | | |/ _ \ '_ ` _ \ / _ \ __| '_ \ / _ \ '__|   *
// *   | |_| |  __/ | | | | |  __/ |_| | | |  __/ |      *
// *   |____/ \___|_| |_| |_|\___|\__|_| |_|\___|_|      *
// *******************************************************
// Demether Finance: https://github.com/demetherdefi

// Primary Author(s)
// Juan C. Dorado: https://github.com/jdorado/

import { OFTUpgradeable } from "@layerzerolabs/lz-evm-oapp-v2_upgradable/contracts/oft/OFTUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Demether Open Fungible Token (DOFT)
/// @dev Extends OFTUpgradeable for cross-chain capabilities and UUPSUpgradeable for upgradability.
/// @notice Implements an ERC20 token with upgradability and cross-chain functionalities.
contract DOFT is OFTUpgradeable, UUPSUpgradeable {
    error ImplementationIsNotContract(address newImplementation);
    error UnauthorizedMinter(address caller);

    address private _minter;

    /// @notice Constructor with LayerZero endpoint.
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {}

    /// @dev Ensures that only the designated minter can execute.
    modifier onlyMinter() {
        if (msg.sender != _minter) {
            revert UnauthorizedMinter(msg.sender);
        }
        _;
    }

    /// @notice Initializes the contract with token name, symbol, initial delegate, and minter.
    /// @param _name Token name.
    /// @param _symbol Token symbol.
    /// @param _delegate Initial owner of the token.
    /// @param _minterAddress Address granted permission to mint and burn tokens.
    function initialize(
        string memory _name,
        string memory _symbol,
        address _delegate,
        address _minterAddress
    ) external initializer onlyProxy {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init();
        _transferOwnership(_delegate);
        _minter = _minterAddress; // Sets the minter.
    }

    /// @notice Mints tokens to a specified address.
    /// @param _to Recipient address.
    /// @param _amount Amount of tokens to mint.
    /// @return True if the mint was successful.
    function mint(address _to, uint256 _amount) external onlyMinter returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /// @notice Burns tokens from a specified address.
    /// @param _from Source address.
    /// @param _amount Amount of tokens to burn.
    /// @return True if the burn was successful.
    function burn(address _from, uint256 _amount) external onlyMinter returns (bool) {
        _burn(_from, _amount);
        return true;
    }

    /// @notice Assigns a new minter address.
    /// @param _newMinter New minter address
    function setMinter(address _newMinter) external onlyOwner {
        _minter = _newMinter;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
