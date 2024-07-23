// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLockTest is TestSetup {
    error UnauthorizedService(address caller);

    TimelockController internal timeLock;

    function setUp() public override {
        super.setUp();

        // set-up TimeLock
        address[] memory proposers = new address[](1);
        proposers[0] = owner;
        timeLock = new TimelockController(1 days, proposers, proposers, owner);

        // transfer ownership of the contracts to the TimeLock
        vm.prank(owner);
        depositsManagerL1.transferOwnership(address(timeLock));
    }

    function test_timeLock() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedService.selector, owner));
        depositsManagerL1.pause();

        vm.prank(address(timeLock));
        depositsManagerL1.pause();

        // unpause with timelock
        bytes memory data = abi.encodeWithSignature("unpause()");
        _timeLock(address(depositsManagerL1), data);
    }

    function _timeLock(address target, bytes memory data) public {
        // Prepare the data with the address argument
        bytes32 salt = keccak256("some-random-salt");

        // Schedule the transaction
        vm.prank(owner);
        timeLock.schedule(target, 0, data, bytes32(0), salt, 1 days);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        // Execute the transaction
        vm.prank(owner);
        timeLock.execute(target, 0, data, bytes32(0), salt);
    }
}
