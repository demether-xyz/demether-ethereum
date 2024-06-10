// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";

contract TestL2Setup is TestSetup, TestHelper {

    DemOFT internal l2token;

    function setUp() public override(TestHelper, TestSetup) {
        TestHelper.setUp();

        // deploy token
//        address endpoint;
//        l2token = new DemOFT("", "", endpoint, admin);
    }
}
