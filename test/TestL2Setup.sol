// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {DepositsManager} from "../src/DepositsManager.sol";
import "./mocks/WETH.sol";

contract TestL2Setup is TestSetup {
    DOFT internal l2token;
    DepositsManager internal depositsManager;
    WETH public wETH;

    function setUp() public override {
        TestSetup.setUp();

        wETH = new WETH();

        // deploy DepositsManager
        data = abi.encodeWithSignature(
            "initialize(address,address)",
            address(wETH),
            owner
        );
        depositsManager = DepositsManager(
            payable(proxy.deploy(address(new DepositsManager()), admin, data))
        );

        // deploy token
        l2token = new DOFT(
            "",
            "",
            address(endpoints[l2Eid]),
            address(depositsManager)
        );
        vm.label(address(l2token), "l2token");

        // setters in DepositsManager
        vm.prank(owner);
        depositsManager.setToken(address(l2token));
    }
}
