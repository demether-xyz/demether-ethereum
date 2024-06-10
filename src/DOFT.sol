// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

/*
TODO
    Make Upgradable using pattern https://blastscan.io/address/0x20ee00f43ef299dba82ba6fef537756dabe38cc7#code
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
}
