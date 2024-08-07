// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "./TestSetup.sol";
import { IDepositsManager } from "../src/interfaces/IDepositsManager.sol";
import { DepositsManagerL2 } from "../src/DepositsManagerL2.sol";
import { OwnableAccessControl } from "../src/OwnableAccessControl.sol";

contract NativeMintingL2_Rates is TestSetup {
    error RateStale();

    function test_L2_Rate_SetMaxRateStaleness() external {
        vm.startPrank(role.owner);
        depositsManagerL2.setMaxRateStaleness(1 days);
        assertEq(depositsManagerL2.maxRateStaleness(), 1 days);
        vm.stopPrank();
    }

    function test_L2_Rate_RevertWhenSetMaxRateStalenessByNonOwner() external {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        depositsManagerL2.setMaxRateStaleness(1 days);
        vm.stopPrank();
    }

    function test_L2_Rate_GetConversionAmountWithFreshRate() external {
        // Simulate a fresh rate update
        syncRate();

        uint256 amountOut = depositsManagerL2.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function test_L2_Rate_RevertGetConversionAmountWithStaleRate() external {
        // Move time forward beyond the staleness threshold
        vm.warp(block.timestamp + 5 days);

        vm.expectRevert(abi.encodeWithSelector(RateStale.selector));
        depositsManagerL2.getConversionAmount(100 ether);
    }

    function test_L2_Rate_GetConversionAmountAfterRateUpdate() external {
        // Move time forward beyond the staleness threshold
        vm.warp(block.timestamp + 5 days);

        // Simulate a fresh rate update
        syncRate();

        uint256 amountOut = depositsManagerL2.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }
}
