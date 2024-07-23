// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract EigenLayerTest is TestSetup {
    function test_EigenLayer_delegate() public {
        vm.prank(role.owner);
        liquidityPool.delegateEigenLayer(OPERATOR);
    }
}
