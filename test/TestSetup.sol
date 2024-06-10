// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {DemOFT} from "../src/DemOFT.sol";

contract TestSetup is Test {
    address internal admin;

    function setUp() public virtual {
        admin = vm.addr(uint256(0x123));
        vm.label(admin, "Admin");
    }
}
