// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {DepositsManagerL2, IMessenger} from "../src/DepositsManagerL2.sol";
import "./mocks/WETH.sol";
import "./mocks/StarGateMock.sol";

contract TestL2Setup is TestSetup {
    DOFT internal l2token;
    DepositsManagerL2 internal depositsManagerL2;
    WETH public wETHL2;

    function setUp() public override {
        TestSetup.setUp();

        wETHL2 = new WETH();
        StarGateMock stargateL2 = new StarGateMock();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature(
            "initialize(address,address,bool)",
            address(wETHL2),
            owner,
            false
        );
        depositsManagerL2 = DepositsManagerL2(
            payable(proxy.deploy(address(new DepositsManagerL2()), admin, data))
        );

        // deploy token
        l2token = new DOFT(
            "",
            "",
            address(endpoints[l2Eid]),
            address(depositsManagerL2)
        );
        vm.label(address(l2token), "l2token");

        // deploy Messenger
        data = abi.encodeWithSignature(
            "initialize(address,address,address)",
            address(wETHL2),
            address(depositsManagerL2),
            owner
        );
        Messenger messenger = Messenger(
            payable(proxy.deploy(address(new Messenger()), admin, data))
        );

        // setters in DepositsManagerL2.sol
        vm.startPrank(owner);
        depositsManagerL2.setToken(address(l2token));
        depositsManagerL2.setMessenger(address(messenger));
        messenger.setSyncSettings(
            l1Eid,
            IMessenger.Settings(
                STARGATE,
                address(stargateL2),
                l1Eid,
                address(depositsManagerL1),
                10 gwei,
                1e15
            )
        );
        vm.stopPrank();

        // todo set token peers >> test L1 to L2 transfers
    }
}
