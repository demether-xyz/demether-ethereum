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

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

/*
TODO
    Make Upgradable using pattern https://blastscan.io/address/0x20ee00f43ef299dba82ba6fef537756dabe38cc7#code
    Determine ownership flow
*/

contract DOFT is OFT {
    /// @notice Initializes the DOFT.sol.sol contract.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _lzEndpoint The LayerZero endpoint address.
    /// @param _delegate The address to transfer ownership to.
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) {
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
}
