// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract MintTest is TestSetup {
    function test_RevertWhenMintCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        l1token.mint(address(bob), 10 ether);
        vm.stopPrank();
    }
}

contract BurnTest is TestSetup {
    function test_RevertWhenBurnCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        l1token.burn(address(bob), 10 ether);
        vm.stopPrank();
    }
}
