// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

contract NativeMintingL1 is TestSetup {
    function test_L1_minting_rate() public {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 100 ether);
    }

    function test_L1_deposit_weth() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{value: amount}();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount);
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_deposit_eth() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = address(this).balance;
        depositsManagerL1.depositETH{value: amount}();
        assertEq(address(this).balance, balanceBefore - amount);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function test_L1_add_liquidity() public {
        assertEq(depositsManagerL1.getRate(), 1 ether);
        depositsManagerL1.depositETH{value: 100 ether}();
        depositsManagerL1.addLiquidity();

        // create rewards in the pool
        _rewards(10 ether);

        // accounts for the 10% protocol fee
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // add liquidity
        depositsManagerL1.depositETH{value: 109 ether}();
        depositsManagerL1.addLiquidity();
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(liquidityPool.totalAssets(), 218 ether);
        assertEq(liquidityPool.totalShares(), 200 ether);
    }

    function test_L1_sync_rate() public {
        depositsManagerL1.depositETH{value: 100 ether}();
        depositsManagerL1.addLiquidity();

        assertEq(depositsManagerL1.getRate(), 1 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // increase rate L1
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // sync L2
        _sync_rate();
        assertEq(depositsManagerL2.getRate(), 1.09 ether);
    }

    function test_L1_quote() public {
        assert(messengerL1.quoteLayerZero(l2Eid) > 0);
    }
}

// contract L1InitializeTest is TestSetup {
//     function test_RevertWhenPassedZeroAddress() external {
//         data = abi.encodeWithSignature("initialize(address,address,bool)", address(0), owner, false);
//         vm.expectRevert(InvalidAddress.selector);
//         proxy.deploy(address(new DepositsManagerL1()), admin, data);

//         data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL1), address(0), false);
//         vm.expectRevert(InvalidAddress.selector);
//         proxy.deploy(address(new DepositsManagerL1()), admin, data);
//     }
// }

contract DepositTest is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.deposit(0);
        vm.stopPrank();
    }

    function test_RevertWhenL1NotApprovedForUsingWETH() external {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Amount in zero"));
        depositsManagerL1.deposit(0);
        vm.stopPrank();
    }
}

contract DepositETHTest is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.depositETH();
        vm.stopPrank();
    }

    function test_RevertWhenNativeTokenNotSupported() external {
        data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL1), owner, false);
        DepositsManagerL1 depositsManager = DepositsManagerL1(payable(proxy.deploy(address(new DepositsManagerL1()), admin, data)));

        vm.startPrank(owner);
        vm.expectRevert(bytes("Native token not supported"));
        depositsManager.depositETH();
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroETH() external {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Amount in zero"));
        depositsManagerL1.depositETH();
        vm.stopPrank();
    }
}

contract AddLiquidityL1Test is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.addLiquidity();
        vm.stopPrank();
    }
}

contract SyncRateL1Test is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.addLiquidity();
        vm.stopPrank();
    }
}

contract SyncTokensTest is TestSetup {
    function test_RevertWhenSyncTokensCallerIsNotAuthorised() external {
        vm.startPrank(owner);
        vm.expectRevert(Unauthorized.selector);
        messengerL1.syncTokens(0, 0, address(bob));
        vm.stopPrank();
    }
}

contract SyncMessageTest is TestSetup {
    function test_RevertWhenSyncMessageCallerIsNotAuthorised() external {
        vm.startPrank(owner);
        vm.expectRevert(Unauthorized.selector);
        messengerL1.syncMessage(0, bytes(""), address(bob));
        vm.stopPrank();
    }
}

contract SetSettingsMessagesTest is TestSetup {
    function test_RevertWhenSetSettingsMessagesCallerIsNotOwner() external {
        IMessenger.Settings memory setting;
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        messengerL1.setSettingsMessages(0, setting);
        vm.stopPrank();
    }
}

contract SetSettingsTokensTest is TestSetup {
    function test_RevertWhenSetSettingsTokensCallerIsNotOwner() external {
        IMessenger.Settings memory setting;
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
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
        messengerL1.setRouters(_bridgeIds ,_routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedArrayWithInvalidLengths() external {
        uint8[] memory _bridgeIds = new uint8[](2);
        address[] memory _routers = new address[](1);

        vm.startPrank(owner);
        vm.expectRevert(InvalidParametersLength.selector);
        messengerL1.setRouters(_bridgeIds ,_routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidRouterAddress() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        messengerL1.setRouters(_bridgeIds ,_routers, address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidOwner() external {
        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);

        _routers[0] = address(bob);
        _bridgeIds[0] = 1;
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        messengerL1.setRouters(_bridgeIds ,_routers, address(0));
        vm.stopPrank();
    }
}

contract AddLiquidityTest is TestSetup {
    function test_RevertWhenAddLiquidityCallerIsNotAuthorised() external {
        vm.startPrank(owner);
        vm.expectRevert(Unauthorized.selector);
        liquidityPool.addLiquidity();
        vm.stopPrank();
    }
}

contract SetFraxMinterTest is TestSetup {
    function test_RevertWhenSetFraxMinterCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setFraxMinter(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.setFraxMinter(address(0));
        vm.stopPrank();
    }
}

contract DelegateEigenLayerTest is TestSetup {
    function test_RevertWhenDelegateEigenLayerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.delegateEigenLayer(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.delegateEigenLayer(address(0));
        vm.stopPrank();
    }
}

contract SetEigenLayerTest is TestSetup {
    function test_RevertWhenSetEigenLayerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setEigenLayer(address(bob),address(bob),address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(0),address(bob),address(bob));

        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob),address(0),address(bob));

        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.setEigenLayer(address(bob),address(bob),address(0));
        vm.stopPrank();
    }
}

contract SetProtocolFeeTest is TestSetup {
    function test_RevertWhenSetProtocolFeeCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolFee(10);
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidFee.selector);
        liquidityPool.setProtocolFee(1 ether);
        vm.stopPrank();
    }
}

contract SetProtocolTreasuryTest is TestSetup {
    function test_RevertWhenSetProtocolTreasuryCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        liquidityPool.setProtocolTreasury(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        liquidityPool.setProtocolTreasury(address(0));
        vm.stopPrank();
    }
}

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

contract SetTokenL1Test is TestSetup {
    function test_RevertWhenSetTokenCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setToken(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        depositsManagerL1.setToken(address(0));
        vm.stopPrank();
    }
}

contract SetLiquidityPoolL1Test is TestSetup {
    function test_RevertWhenSetLiquidityPoolCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setLiquidityPool(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        depositsManagerL1.setLiquidityPool(address(0));
        vm.stopPrank();
    }
}

contract SetMessengerL1Test is TestSetup {
    function test_RevertWhenSetMessengerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setMessenger(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(InvalidAddress.selector);
        depositsManagerL1.setMessenger(address(0));
        vm.stopPrank();
    }
}

contract PauseL1Test is TestSetup {
    function test_RevertWhenPauseCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.pause();
        vm.stopPrank();
    }

    function test_RevertWhenAlreadyPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.pause();
        vm.stopPrank();
    }
}

contract UnpauseL1Test is TestSetup {
    function test_RevertWhenUnpauseCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenNotPaused() external {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Pausable: not paused"));
        depositsManagerL1.unpause();
        vm.stopPrank();
    }
}




