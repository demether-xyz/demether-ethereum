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
    /// @notice Constructor with LayerZero endpoint.
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {}

    /// @notice Initializes the DOFT.sol.sol contract.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _delegate The address to transfer ownership to.
    function initialize(string memory _name, string memory _symbol, address _delegate) external initializer onlyProxy {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init();
        _transferOwnership(_delegate);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyOwner returns (bool) {
        _burn(_from, _amount);
        return true;
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
