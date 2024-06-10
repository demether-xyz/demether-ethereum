// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 _value) external;
    function balanceOf(address _user) external view returns (uint256);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function transferFrom(
        address _src,
        address _dst,
        uint256 _amount
    ) external returns (bool);
}
