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
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title Demether Open Fungible Token (DOFT)
/// @dev Extends OFTUpgradeable for cross-chain capabilities and UUPSUpgradeable for upgradability.
/// @notice Implements an ERC20 token with upgradability and cross-chain functionalities.
contract DOFT is ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Thrown when attempting to upgrade to an implementation that is not a contract.
    /// @param newImplementation The address of the invalid implementation.
    error ImplementationIsNotContract(address newImplementation);

    /// @notice Thrown when an unauthorized address attempts to mint or burn tokens.
    /// @param caller The address that attempted the unauthorized action.
    error UnauthorizedMinter(address caller);

    /// @notice Thrown when an invalid (usually zero) address is provided where a valid address is required.
    error InvalidAddress();

    /// @notice Emitted when the minter address is changed.
    /// @param oldMinter The address of the previous minter.
    /// @param newMinter The address of the new minter.
    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    address private _minter;

    /// @notice Constructor with LayerZero endpoint.
    constructor(address _lzEndpoint) {}

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
        if (_delegate == address(0)) revert InvalidAddress();

        __DOFT_init(_name, _symbol, _delegate, _minterAddress);
    }

    /// @notice Internal function to initialize the contract.
    /// @param _name Token name.
    /// @param _symbol Token symbol.
    /// @param _delegate Initial owner of the token.
    /// @param _minterAddress Address granted permission to mint and burn tokens.
    /// @dev Calls parent initializers in the correct order and then calls the contract-specific initializer.
    // solhint-disable-next-line
    function __DOFT_init(string memory _name, string memory _symbol, address _delegate, address _minterAddress) internal onlyInitializing {
//        __OFT_init(_name, _symbol, _delegate);
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();
        __DOFT_init_unchained(_delegate, _minterAddress);
    }

    /// @notice Internal function to initialize the state variables specific to DOFT.

    /// @param _delegate Initial owner of the token.
    /// @param _minterAddress Address granted permission to mint and burn tokens.
    // solhint-disable-next-line
    function __DOFT_init_unchained(address _delegate, address _minterAddress) internal onlyInitializing {
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
        address oldMinter = _minter;
        // slither-disable-next-line missing-zero-check
        _minter = _newMinter;
        emit MinterChanged(oldMinter, _newMinter);
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
