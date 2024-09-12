// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IfrxETHMinter {
    function submitAndDeposit(address recipient) external payable returns (uint256 shares);
    function submitAndGive(address recipient) external payable;
    function sfrxETHToken() external view returns (address);
}
