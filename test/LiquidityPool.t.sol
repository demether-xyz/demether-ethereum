// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import "../src/interfaces/ILiquidityPool.sol";
import "../src/OwnableAccessControl.sol";

contract LiquidityPoolTest is TestSetup {
    function setUp() public virtual override {
        super.setUp();
    }
}

contract AddLiquidityTest is LiquidityPoolTest {
    function test_RevertWhenAddLiquidityCallerIsNotAuthorised() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.Unauthorized.selector);
        liquidityPool.addLiquidity(false);
        vm.stopPrank();
    }
}

contract SetFraxMinterTest is LiquidityPoolTest {
    function test_RevertWhenSetFraxMinterCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setFraxMinter(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.setFraxMinter(address(0));
        vm.stopPrank();
    }
}

contract DelegateEigenLayerTest is LiquidityPoolTest {
    function test_RevertWhenDelegateEigenLayerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControl.UnauthorizedService.selector, bob));
        liquidityPool.delegateEigenLayer(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.delegateEigenLayer(address(0));
        vm.stopPrank();
    }
}

contract SetEigenLayerTest is LiquidityPoolTest {
    function test_RevertWhenSetEigenLayerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setEigenLayer(address(bob), address(bob), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(0), address(bob), address(bob));

        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob), address(0), address(bob));

        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob), address(bob), address(0));
        vm.stopPrank();
    }
}

contract SetProtocolFeeTest is LiquidityPoolTest {
    function test_SetProtocolFeeShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(liquidityPool.protocolFee(), 1e17);

        liquidityPool.setProtocolFee(100 gwei);

        assertEq(liquidityPool.protocolFee(), 100 gwei);
        vm.stopPrank();
    }

    function test_RevertWhenSetProtocolFeeCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolFee(10);
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidFee() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.InvalidFee.selector);
        liquidityPool.setProtocolFee(2 ether);
        vm.stopPrank();
    }
}

contract SetProtocolTreasuryTest is LiquidityPoolTest {
    function test_SetProtocolTreasuryShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(address(liquidityPool.protocolTreasury()), address(role.owner));

        liquidityPool.setProtocolTreasury(payable(address(bob)));

        assertEq(address(liquidityPool.protocolTreasury()), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenSetProtocolTreasuryCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolTreasury(payable(address(bob)));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        liquidityPool.setProtocolTreasury(payable(address(0)));
        vm.stopPrank();
    }
}
