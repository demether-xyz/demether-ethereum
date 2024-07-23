// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract NativeMintingL2 is TestSetup {
    error NativeTokenNotSupported();

    function test_L2_minting_rate() public {
        uint256 amountOut = depositsManagerL2.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function test_L2_deposit_weth() public {
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        assertEq(wETHL2.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);
    }

    function test_L2_deposit_eth() public {
        vm.expectRevert(NativeTokenNotSupported.selector);
        depositsManagerL2.depositETH{ value: 100 ether }(0, 0, address(0));
    }

    function test_L2_bridged_deposit_weth() public {
        uint256 fee = 100;
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit{ value: fee }(amount, l1Eid, fee, address(0));
        assertEq(l2token.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(depositsManagerL1)), 0);
        verifyPackets(l1Eid, addressToBytes32(address(l1token)));
        assertEq(l1token.balanceOf(address(this)), 99.9 ether);
    }

    function test_L2_sync_tokens() public {
        // deposit L2
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        // 0.1% fee captured to cover slippage
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);

        // sync tokens to L1 and receive less
        uint256 fee = 10 gwei;
        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        depositsManagerL2.syncTokens{ value: fee }(balance);
        assertEq(wETHL2.balanceOf(address(depositsManagerL2)), 0);

        // 0.2% paid to the router
        assertEq(address(depositsManagerL1).balance, 99.8 ether);
    }

    /// @dev Slippage cost higher than fee, creates a whole
    function test_L2_high_slippage() public {
        // initialize the rate on L1
        depositsManagerL1.depositETH{ value: 100 ether }(0, 0, address(0));
        depositsManagerL1.processLiquidity();
        assertEq(depositsManagerL1.getRate(), 1 ether);

        test_L2_sync_tokens();
        depositsManagerL1.processLiquidity();

        uint256 oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 199.8 ether);
        assertEq(depositsManagerL1.getRate(), 1 ether);

        uint256 missingETH = (oftSupply * depositsManagerL1.getRate()) / 1e18 - liquidityPool.totalAssets();
        assertEq(missingETH, 0.1 ether);

        // add surplus to cover the gap
        liquidityPool.addLiquidity{ value: 1 ether }();

        oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 200.8 ether);
        assertEq(depositsManagerL1.getRate(), 1 ether);
    }

    /// @dev Rewards increase higher than rate creates a whole
    function test_L2_high_rewards() public {
        stargateL2.setSlippage(0);

        // initialize the rate on L1 + add rewards
        depositsManagerL1.depositETH{ value: 100 ether }(0, 0, address(0));
        depositsManagerL1.processLiquidity();
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // deposit L2 at 1.0 rate, sync not happened yet / or bridge while rate went up
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        // 0.1% fee captured to cover slippage
        assertEq(l2token.balanceOf(address(this)), 99.9 ether); // mints more than should

        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        depositsManagerL2.syncTokens{ value: 10 gwei }(balance);
        assertEq(address(depositsManagerL1).balance, 100 ether);
        depositsManagerL1.processLiquidity();

        uint256 oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 209 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        uint256 missingETH = (oftSupply * depositsManagerL1.getRate()) / 1e18 - liquidityPool.totalAssets();
        assertEq(missingETH, 8.891 ether);
    }
}
