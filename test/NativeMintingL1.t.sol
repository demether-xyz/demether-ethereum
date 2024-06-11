// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract NativeMintingL1 is TestSetup {
    function test_L1_native_minting_rate() public {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function test_L1_native_minting_deposit() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{value: amount}();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount);
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 99.9 ether);
    }
}
