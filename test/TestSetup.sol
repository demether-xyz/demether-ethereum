// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {DemOFT} from "../src/DemOFT.sol";

contract TestSetup is Test, TestHelper {
    address internal admin;

    uint32 l1Eid = 1;
    uint32 l2Eid = 2;
    DemOFT internal l1token;

    function setUp() public virtual override {
        admin = vm.addr(uint256(0x123));
        vm.label(admin, "Admin");

        // LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // token
        l1token = new DemOFT("", "", address(endpoints[l1Eid]), admin);
        vm.label(address(l1token), "l1token");
    }
}
