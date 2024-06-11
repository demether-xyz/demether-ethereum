// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract NativeMintingL1 is TestSetup {
    function test_L1_native_minting_rate() public {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 100 ether);
    }

    function test_L1_deposit_weth() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{value: amount}();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount);
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_deposit_eth() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = address(this).balance;
        depositsManagerL1.depositETH{value: amount}();
        assertEq(address(this).balance, balanceBefore - amount);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_add_liquidity() public {
        assertEq(depositsManagerL1.getRate(), 1 ether);
        depositsManagerL1.depositETH{value: 100 ether}();
        depositsManagerL1.addLiquidity();

        // create rewards in the pool
        address pool = address(depositsManagerL1.pool());
        vm.deal(pool, pool.balance + 10 ether);
        assertEq(depositsManagerL1.getRate(), 1.1 ether);
    }
}
