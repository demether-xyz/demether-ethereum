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

import {OFTUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2_upgradable/contracts/oft/OFTUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DOFT is OFTUpgradeable, UUPSUpgradeable {
    address private _minter;

    /// @notice Constructor with LayerZero endpoint.
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {}

    /// @notice Checks if the caller is the designated minter.
    modifier onlyMinter() {
        require(msg.sender == _minter, "Caller is not the minter");
        _;
    }

    /// @notice Initializes the DOFT.sol contract.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _delegate The address to transfer ownership to.
    /// @param _minterAddress The address of the minter.
    function initialize(
        string memory _name,
        string memory _symbol,
        address _delegate,
        address _minterAddress
    ) external initializer onlyProxy {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init();
        _transferOwnership(_delegate);
        _minter = _minterAddress; // Set the minter
    }

    /// @notice Mints tokens to the specified address.
    /// @param _to Address to mint tokens to.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external onlyMinter returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /// @notice Burns tokens from the specified address.
    /// @param _from Address from which tokens will be burned.
    /// @param _amount The amount of tokens to burn.
    function burn(address _from, uint256 _amount) external onlyMinter returns (bool) {
        _burn(_from, _amount);
        return true;
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
