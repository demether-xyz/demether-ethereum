// SPDX-License-Identifier: BUSL-1.1
// modified version of https://github.com/itstargetconfirmed/wrapped-ether/blob/master/contracts/WETH.sol
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice An implementation of Wrapped Ether.
/// @author Anderson Singh.

contract WETH is ERC20 {
    error InsufficientBalance(uint256 available, uint256 required);
    constructor() ERC20("Wrapped Ether", "WETH") {}

    /// @dev mint tokens for sender based on amount of ether sent.
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    /// @dev withdraw ether based on requested amount and user balance.
    function withdraw(uint256 _amount) external {
        uint256 balance = balanceOf(msg.sender);
        if (balance < _amount) {
            revert InsufficientBalance(balance, _amount);
        }
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(_amount);
    }

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }
}
