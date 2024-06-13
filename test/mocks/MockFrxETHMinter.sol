// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockFrxETHMinter {
    IsfrxETH public immutable sfrxETHToken;

    // todo in constructor deplou a ERC20 token for sfrxETHToken

    function submitAndDeposit(address recipient) external payable returns (uint256 shares) {
        require(msg.value > 0, "Must send ETH to submit and deposit");

    }
}