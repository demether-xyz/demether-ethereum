// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "./TestSetup.sol";

contract EigenLayerTest is TestSetup {
    function testEigenLayerDelegate() public {
        vm.prank(role.owner);
        liquidityPool.delegateEigenLayer(OPERATOR);
    }
}
