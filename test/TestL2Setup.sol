// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {DepositsManager} from "../src/DepositsManager.sol";

contract TestL2Setup is TestSetup {
    DOFT internal l2token;

    function setUp() public override {
        TestSetup.setUp();

        // deploy token
        l2token = new DOFT("", "", address(endpoints[l2Eid]), admin);
        vm.label(address(l2token), "l2token");

        // deploy DepositsManager

    }
}
