// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestL2Setup.sol";

contract NativeMintingL2 is TestL2Setup {
    function test_native_minting_rate() public {
        uint256 amountOut = depositsManager.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function test_native_minting_deposit() public {
        uint256 amount = 100 ether;
        wETH.deposit{value: amount}();
        wETH.approve(address(depositsManager), amount);
        depositsManager.deposit(amount);
        assertEq(wETH.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);
    }
}
