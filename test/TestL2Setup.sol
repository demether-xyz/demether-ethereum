// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {DepositsManagerL2} from "../src/DepositsManagerL2.sol";
import "./mocks/WETH.sol";

contract TestL2Setup is TestSetup {
    DOFT internal l2token;
    DepositsManagerL2 internal depositsManagerL2;
    WETH public wETHL2;

    function setUp() public override {
        TestSetup.setUp();

        wETHL2 = new WETH();

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
            "initialize(address,address)",
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
        vm.stopPrank();
    }
}
