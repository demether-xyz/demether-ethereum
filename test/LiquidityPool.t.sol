// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import "../src/interfaces/ILiquidityPool.sol";

contract LiquidityPoolTest is TestSetup {
    function setUp() public virtual override {
        super.setUp();
    }
}

contract AddLiquidityTest is LiquidityPoolTest {
    function test_RevertWhenAddLiquidityCallerIsNotAuthorised() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.Unauthorized.selector);
        liquidityPool.addLiquidity();
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
        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
        liquidityPool.setFraxMinter(address(0));
        vm.stopPrank();
    }
}

contract DelegateEigenLayerTest is LiquidityPoolTest {
    function test_RevertWhenDelegateEigenLayerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.delegateEigenLayer(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
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
        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(0), address(bob), address(bob));

        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob), address(0), address(bob));

        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob), address(bob), address(0));
        vm.stopPrank();
    }
}

contract SetProtocolFeeTest is LiquidityPoolTest {
    function test_RevertWhenSetProtocolFeeCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolFee(10);
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.InvalidFee.selector);
        liquidityPool.setProtocolFee(1 ether);
        vm.stopPrank();
    }
}

contract SetProtocolTreasuryTest is LiquidityPoolTest {
    function test_RevertWhenSetProtocolTreasuryCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolTreasury(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(ILiquidityPool.InvalidAddress.selector);
        liquidityPool.setProtocolTreasury(address(0));
        vm.stopPrank();
    }
}
