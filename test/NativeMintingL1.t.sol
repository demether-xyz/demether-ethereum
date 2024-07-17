// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "./TestSetup.sol";

contract NativeMintingL1 is TestSetup {
    function testL1MintingRate() public view {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 100 ether);
    }

    function testL1DepositWeth() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{ value: amount }();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount);
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function testL1DepositEth() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = address(this).balance;
        depositsManagerL1.depositETH{ value: amount }();
        assertEq(address(this).balance, balanceBefore - amount);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function testL1AddLiquidity() public {
        assertEq(depositsManagerL1.getRate(), 1 ether);
        depositsManagerL1.depositETH{ value: 100 ether }();
        depositsManagerL1.addLiquidity();

        // create rewards in the pool
        _rewards(10 ether);

        // accounts for the 10% protocol fee
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // add liquidity
        depositsManagerL1.depositETH{ value: 109 ether }();
        depositsManagerL1.addLiquidity();
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(liquidityPool.totalAssets(), 218 ether);
        assertEq(liquidityPool.totalShares(), 200 ether);
    }

    function testL1SyncRate() public {
        depositsManagerL1.depositETH{ value: 100 ether }();
        depositsManagerL1.addLiquidity();

        assertEq(depositsManagerL1.getRate(), 1 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // increase rate L1
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // sync L2
        syncRate();
        assertEq(depositsManagerL2.getRate(), 1.09 ether);
    }

    function testL1Quote() public view {
        assert(messengerL1.quoteLayerZero(L2_EID) > 0);
    }
}
