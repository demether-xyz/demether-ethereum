// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract NativeMintingL1 is TestSetup {
    function test_L1_minting_rate() public {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 100 ether);
    }

    function test_L1_deposit_weth() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{value: amount}();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount, 0, 0, address(0));
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_deposit_eth() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = address(this).balance;
        depositsManagerL1.depositETH{value: amount}(0, 0, address(0));
        assertEq(address(this).balance, balanceBefore - amount);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_bridged_deposit_weth() public {
        uint256 fee = 100;
        uint256 amount = 100 ether;
        wETHL1.deposit{value: amount}();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit{value: fee}(amount, l2Eid, fee, address(0));
        assertEq(l1token.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(depositsManagerL1)), 0);
        verifyPackets(l2Eid, addressToBytes32(address(l2token)));
        assertEq(l2token.balanceOf(address(this)), amount);
    }

    function test_L1_bridged_deposit_eth() public {
        uint256 fee = 100;
        uint256 amount = 10 ether;
        depositsManagerL1.depositETH{value: amount + fee}(l2Eid, fee, address(0));
        assertEq(l1token.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(depositsManagerL1)), 0);
        verifyPackets(l2Eid, addressToBytes32(address(l2token)));
        assertEq(l2token.balanceOf(address(this)), amount);
    }

    function test_L1_add_liquidity() public {
        assertEq(depositsManagerL1.getRate(), 1 ether);
        depositsManagerL1.depositETH{value: 100 ether}(0, 0, address(0));
        depositsManagerL1.addLiquidity();

        // create rewards in the pool
        _rewards(10 ether);

        // accounts for the 10% protocol fee
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // add liquidity
        depositsManagerL1.depositETH{value: 109 ether}(0, 0, address(0));
        depositsManagerL1.addLiquidity();
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(liquidityPool.totalAssets(), 218 ether);
        assertEq(liquidityPool.totalShares(), 200 ether);
    }

    function test_L1_sync_rate() public {
        depositsManagerL1.depositETH{value: 100 ether}(0, 0, address(0));
        depositsManagerL1.addLiquidity();

        assertEq(depositsManagerL1.getRate(), 1 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // increase rate L1
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // sync L2
        _sync_rate();
        assertEq(depositsManagerL2.getRate(), 1.09 ether);
    }

    function test_L1_quote() public view {
        assert(messengerL1.quoteLayerZero(l2Eid) > 0);
    }
}
