// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import "./mocks/MockSymbiotic.sol";

contract SymbioticTest is TestSetup {
    uint8 internal constant STRATEGY_SYMBIOTIC = 1;
    MockDefaultCollateral internal collateral;

    function setUp() public override {
        super.setUp();

        collateral = new MockDefaultCollateral(IERC20(address(sfrxETHtoken)), "", "", 1000 ether);

        // set strategy
        vm.prank(role.owner);
        liquidityPool.setSymbiotic(address(collateral));

        // enable symbiotic
        vm.prank(role.owner);
        liquidityPool.setStrategy(STRATEGY_SYMBIOTIC);
    }

    function test_Symbiotic_deposit() public {
        depositsManagerL1.depositETH{ value: 100 ether }(0, 0, address(0));
        depositsManagerL1.processLiquidity();
        assertEq(collateral.balanceOf(address(liquidityPool)), 50 ether); // 2.0 rate
        assertEq(depositsManagerL1.getRate(), 1 ether);
        assertEq(liquidityPool.totalAssets(), 100 ether);
    }
}
