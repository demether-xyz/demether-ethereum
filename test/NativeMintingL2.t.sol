// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestL2Setup.sol";

contract NativeMintingL2 is TestL2Setup {
    function test_L2_native_minting_rate() public {
        uint256 amountOut = depositsManagerL2.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function test_L2_deposit_weth() public {
        uint256 amount = 100 ether;
        wETHL2.deposit{value: amount}();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount);
        assertEq(wETHL2.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);
    }

    function test_L2_deposit_eth() public {
        vm.expectRevert("Native token not supported");
        depositsManagerL2.depositETH{value: 100 ether}();
    }

    function test_L2_sync_tokens() public {
        uint256 amount = 100 ether;
        wETHL2.deposit{value: amount}();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount);
        uint256 fee = 10 gwei; // todo get from messenger
        depositsManagerL2.syncTokens{value: fee}();
        assertEq(wETHL2.balanceOf(address(depositsManagerL2)), 0);
        assertEq(address(depositsManagerL1).balance, 99.9 ether);
    }
}
