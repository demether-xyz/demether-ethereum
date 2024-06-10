// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDOFT is IERC20 {
    function mint(address _to, uint256 _amount) external returns (bool);
    function burn(address _from, uint256 _amount) external returns (bool);
}
