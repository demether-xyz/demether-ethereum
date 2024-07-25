// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import "../src/interfaces/IMessenger.sol";
import "../src/OwnableAccessControl.sol";

contract SyncTokensTest is TestSetup {
    function test_RevertWhenSyncTokensCallerIsNotAuthorised() external {
        vm.startPrank(role.owner);
        vm.expectRevert(IMessenger.Unauthorized.selector);
        messengerL1.syncTokens(0, 0, address(bob));
        vm.stopPrank();
    }
}

contract SyncMessageTest is TestSetup {
    function test_RevertWhenSyncMessageCallerIsNotAuthorised() external {
        vm.startPrank(role.owner);
        vm.expectRevert(IMessenger.Unauthorized.selector);
        messengerL1.syncMessage(0, bytes(""), address(bob));
        vm.stopPrank();
    }
}

contract SetSettingsMessagesTest is TestSetup {
    function test_RevertWhenSetSettingsMessagesCallerIsNotOwner() external {
        IMessenger.Settings memory setting;
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControl.UnauthorizedService.selector, bob));
        messengerL1.setSettingsMessages(0, setting);
        vm.stopPrank();
    }
}

contract SetSettingsTokensTest is TestSetup {
    function test_RevertWhenSetSettingsTokensCallerIsNotOwner() external {
        IMessenger.Settings memory setting;
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControl.UnauthorizedService.selector, bob));
        messengerL1.setSettingsTokens(0, setting);
        vm.stopPrank();
    }
}

contract SetRoutersTest is TestSetup {
    function test_RevertWhenSetRoutersCallerIsNotOwner() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        messengerL1.setRouters(_bridgeIds, _routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedArrayWithInvalidLengths() external {
        uint8[] memory _bridgeIds = new uint8[](2);
        address[] memory _routers = new address[](1);

        vm.startPrank(role.owner);
        vm.expectRevert(IMessenger.InvalidParametersLength.selector);
        messengerL1.setRouters(_bridgeIds, _routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidBridge() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        vm.startPrank(role.owner);
        vm.expectRevert(IMessenger.BridgeNotSupported.selector);
        messengerL1.setRouters(_bridgeIds, _routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidRouterAddress() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        _bridgeIds[0] = 1;

        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        messengerL1.setRouters(_bridgeIds, _routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidOwner() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        _routers[0] = address(bob);
        _bridgeIds[0] = 1;
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        messengerL1.setRouters(_bridgeIds, _routers, address(0));
        vm.stopPrank();
    }
}
