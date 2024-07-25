// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract StarGateTest is TestSetup {
    function setUp() public override {
        super.setUp();
        if (!fork_active) return;

        vm.startPrank(role.owner);
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);
        _bridgeIds[0] = STARGATE_V2;
        _routers[0] = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931;
        messengerL1.setRouters(_bridgeIds, _routers, role.owner);
        messengerL1.setSettingsTokens(
            L2_EID,
            IMessenger.Settings(STARGATE_V2, L2_EID, 30110, address(depositsManagerL1), 10 gwei, 25e14, "", true)
        );
        vm.stopPrank();
    }

    function test_fork_StarGate_quote() public {
        if (!fork_active) return;
        (uint256 fee, uint256 amount) = messengerL1.quoteStarGate(L2_EID, 100 ether);
        assertGt(fee, 10 gwei);
        assertGt(amount, 99.9 ether);
    }
}
