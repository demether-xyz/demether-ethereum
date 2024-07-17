// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "./TestSetup.sol";
import { IDepositsManager } from "../src/interfaces/IDepositsManager.sol";

contract DepositManagerL1Test is TestSetup {
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual override {
        super.setUp();
    }
}

contract NativeMintingL1 is DepositManagerL1Test {
    function testL1MintingRate() public view {
        uint256 amountOut = depositsManagerL1.getConversionAmount(100 ether);
        assertEq(amountOut, 100 ether);
    }

    function testL1DepositWeth() public {
        uint256 amount = 100 ether;
        wETHL1.deposit{ value: amount }();
        wETHL1.approve(address(depositsManagerL1), amount);
        depositsManagerL1.deposit(amount);
        assertEq(wETHL1.balanceOf(address(this)), 0);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function testL1DepositEth() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = address(this).balance;
        depositsManagerL1.depositETH{ value: amount }();
        assertEq(address(this).balance, balanceBefore - amount);
        assertEq(l1token.balanceOf(address(this)), 100 ether);
    }

    function testL1AddLiquidity() public {
        assertEq(depositsManagerL1.getRate(), 1 ether);
        depositsManagerL1.depositETH{ value: 100 ether }();
        depositsManagerL1.addLiquidity();

        // create rewards in the pool
        _rewards(10 ether);

        // accounts for the 10% protocol fee
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // add liquidity
        depositsManagerL1.depositETH{ value: 109 ether }();
        depositsManagerL1.addLiquidity();
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(liquidityPool.totalAssets(), 218 ether);
        assertEq(liquidityPool.totalShares(), 200 ether);
    }

    function testL1SyncRate() public {
        depositsManagerL1.depositETH{ value: 100 ether }();
        depositsManagerL1.addLiquidity();

        assertEq(depositsManagerL1.getRate(), 1 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // increase rate L1
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);
        assertEq(depositsManagerL2.getRate(), 1 ether);

        // sync L2
        syncRate();
        assertEq(depositsManagerL2.getRate(), 1.09 ether);
    }

    function testL1Quote() public view {
        assert(messengerL1.quoteLayerZero(L2_EID) > 0);
    }
}

// contract L1InitializeTest is DepositManagerL1Test {
//     function test_RevertWhenPassedZeroAddress() external {
//         data = abi.encodeWithSignature("initialize(address,address,bool)", address(0), owner, false);
//         vm.expectRevert(InvalidAddress.selector);
//         proxy.deploy(address(new DepositsManagerL1()), admin, data);

//         data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL1), address(0), false);
//         vm.expectRevert(InvalidAddress.selector);
//         proxy.deploy(address(new DepositsManagerL1()), admin, data);
//     }
// }

contract DepositTestL1 is DepositManagerL1Test {
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

contract DepositETHTestL1 is DepositManagerL1Test {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.depositETH();
        vm.stopPrank();
    }

    function test_RevertWhenNativeTokenNotSupported() external {
        data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL1), owner, false);
        DepositsManagerL1 depositsManager =
            DepositsManagerL1(payable(proxy.deploy(address(new DepositsManagerL1()), admin, data)));

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

contract GetRateL1Test is DepositManagerL1Test {
    function test_GetRateShouldWorkCorrectly() external {
        assertEq(depositsManagerL1.getRate(), liquidityPool.getRate());
    }
}

contract AddLiquidityL1Test is DepositManagerL1Test {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.addLiquidity();
        vm.stopPrank();
    }
}

contract SyncRateL1Test is DepositManagerL1Test {
    uint32[] _chainId1 = new uint32[](1);
    uint256[] _chainFee1 = new uint256[](1);
    uint256 fee;

    function setUp() public virtual override {
        super.setUp();
        fee = 10 gwei;
        _chainId1[0] = l2Eid;
        _chainFee1[0] = fee;
    }

    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();
        vm.stopPrank();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL1.syncRate{value: fee}(_chainId1, _chainFee1);
    }

    function test_RevertWhenInvalidArraysPassed() external {
        uint32[] memory _chainId2 = new uint32[](2);
        uint256[] memory _chainFee2 = new uint256[](2);

        vm.expectRevert(IDepositsManager.InvalidParametersLength.selector);
        depositsManagerL1.syncRate{value: fee}(_chainId2, _chainFee1);

        vm.expectRevert(IDepositsManager.InvalidParametersLength.selector);
        depositsManagerL1.syncRate{value: fee}(_chainId1, _chainFee2);
    }

    // Note : contract will not reach to InsufficientFee revert line anyway
    // function test_RevertWhenPassedLessFees() external {
    //     _chainFee1[0] = 10 ether;

    //     vm.expectRevert(IDepositsManager.InsufficientFee.selector);
    //     depositsManagerL1.syncRate{value: 1 ether}(_chainId1, _chainFee1);
    // }
}

contract OnMessageReceivedL1Test is DepositManagerL1Test {
    function test_OnMessageReceivedShouldWorkCorrectly() external {
        vm.expectRevert(bytes("not implemented"));
        depositsManagerL1.onMessageReceived(1, bytes(""));
    }
}

contract SetTokenL1Test is DepositManagerL1Test {
    function test_SetTokenShouldWorkCorrectly() external {
        vm.startPrank(owner);
        assertEq(address(depositsManagerL1.token()), address(l1token));

        depositsManagerL1.setToken(address(bob));

        assertEq(address(depositsManagerL1.token()), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenSetTokenCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setToken(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(IDepositsManager.InvalidAddress.selector);
        depositsManagerL1.setToken(address(0));
        vm.stopPrank();
    }
}

contract SetLiquidityPoolL1Test is DepositManagerL1Test {
    function test_SetLiquidityPoolShouldWorkCorrectly() external {
        vm.startPrank(owner);
        assertEq(address(depositsManagerL1.pool()), address(liquidityPool));

        depositsManagerL1.setLiquidityPool(address(bob));

        assertEq(address(depositsManagerL1.pool()), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenSetLiquidityPoolCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setLiquidityPool(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(IDepositsManager.InvalidAddress.selector);
        depositsManagerL1.setLiquidityPool(address(0));
        vm.stopPrank();
    }
}

contract SetMessengerL1Test is DepositManagerL1Test {
    function test_SetMessengerShouldWorkCorrectly() external {
        vm.startPrank(owner);
        assertEq(address(depositsManagerL1.messenger()), address(messengerL1));

        depositsManagerL1.setMessenger(address(bob));

        assertEq(address(depositsManagerL1.messenger()), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenSetMessengerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL1.setMessenger(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(IDepositsManager.InvalidAddress.selector);
        depositsManagerL1.setMessenger(address(0));
        vm.stopPrank();
    }
}

contract PauseL1Test is DepositManagerL1Test {
    function test_PauseShouldWorkCorrectly() external {
        vm.startPrank(owner);
        assertEq(depositsManagerL1.paused(), false);

        vm.expectEmit(true, true, true, true, address(depositsManagerL1));
        emit Paused(address(owner));
        depositsManagerL1.pause();

        assertEq(depositsManagerL1.paused(), true);
        vm.stopPrank();
    }

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

contract UnpauseL1Test is DepositManagerL1Test {
    function test_UnpauseShouldWorkCorrectly() external {
        vm.startPrank(owner);
        depositsManagerL1.pause();

        assertEq(depositsManagerL1.paused(), true);
        vm.expectEmit(true, true, true, true, address(depositsManagerL1));
        emit Unpaused(address(owner));

        depositsManagerL1.unpause();
        assertEq(depositsManagerL1.paused(), false);
        vm.stopPrank();
    }

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
