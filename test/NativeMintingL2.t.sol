// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "./TestSetup.sol";
import { IDepositsManager } from "../src/interfaces/IDepositsManager.sol";
import { DepositsManagerL2 } from "../src/DepositsManagerL2.sol";
import { OwnableAccessControl } from "../src/OwnableAccessControl.sol";

contract NativeMintingL2 is TestSetup {
    error NativeTokenNotSupported();

    function test_L2_minting_rate() public {
        uint256 amountOut = depositsManagerL2.getConversionAmount(100 ether);
        assertEq(amountOut, 99.9 ether);
    }

    function testL2DepositWeth() public {
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        assertEq(wETHL2.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);
    }

    function test_L2_deposit_eth() public {
        vm.expectRevert(NativeTokenNotSupported.selector);
        depositsManagerL2.depositETH{ value: 100 ether }(0, 0, address(0));
    }

    function test_L2_bridged_deposit_weth() public {
        uint256 fee = 100;
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit{ value: fee }(amount, L1_EID, fee, address(0));
        assertEq(l2token.balanceOf(address(this)), 0);
        assertEq(l2token.balanceOf(address(depositsManagerL1)), 0);
        verifyPackets(L1_EID, addressToBytes32(address(l1token)));
        assertEq(l1token.balanceOf(address(this)), 99.9 ether);
    }

    function testL2SyncTokens() public {
        // deposit L2
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        // 0.1% fee captured to cover slippage
        assertEq(l2token.balanceOf(address(this)), 99.9 ether);

        // sync tokens to L1 and receive less
        uint256 fee = 10 gwei;
        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        depositsManagerL2.syncTokens{ value: fee }(balance);
        assertEq(wETHL2.balanceOf(address(depositsManagerL2)), 0);

        // 0.2% paid to the router
        assertEq(address(depositsManagerL1).balance, 99.8 ether);
    }

    /// @dev Slippage cost higher than fee, creates a whole
    function testL2HighSlippage() public {
        // initialize the rate on L1
        depositsManagerL1.depositETH{ value: 100 ether }(0, 0, address(0));
        depositsManagerL1.processLiquidity();
        assertEq(depositsManagerL1.getRate(), 1 ether);

        testL2SyncTokens();
        depositsManagerL1.processLiquidity();

        uint256 oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 199.8 ether);
        assertEq(depositsManagerL1.getRate(), 1 ether);

        uint256 missingETH = (oftSupply * depositsManagerL1.getRate()) / 1e18 - liquidityPool.totalAssets();
        assertEq(missingETH, 0.1 ether);

        // add surplus to cover the gap
        liquidityPool.addLiquidity{ value: 1 ether }();

        oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 200.8 ether);
        assertEq(depositsManagerL1.getRate(), 1 ether);
    }

    /// @dev Rewards increase higher than rate creates a whole
    function testL2HighRewards() public {
        stargateL2.setSlippage(0);

        // initialize the rate on L1 + add rewards
        depositsManagerL1.depositETH{ value: 100 ether }(0, 0, address(0));
        depositsManagerL1.processLiquidity();
        _rewards(10 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        // deposit L2 at 1.0 rate, sync not happened yet / or bridge while rate went up
        uint256 amount = 100 ether;
        wETHL2.deposit{ value: amount }();
        wETHL2.approve(address(depositsManagerL2), amount);
        depositsManagerL2.deposit(amount, 0, 0, address(0));
        // 0.1% fee captured to cover slippage
        assertEq(l2token.balanceOf(address(this)), 99.9 ether); // mints more than should

        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        depositsManagerL2.syncTokens{ value: 10 gwei }(balance);
        assertEq(address(depositsManagerL1).balance, 100 ether);
        depositsManagerL1.processLiquidity();

        uint256 oftSupply = l1token.totalSupply() + l2token.totalSupply();
        assertEq(oftSupply, 199.9 ether);
        assertEq(liquidityPool.totalAssets(), 209 ether);
        assertEq(depositsManagerL1.getRate(), 1.09 ether);

        uint256 missingETH = (oftSupply * depositsManagerL1.getRate()) / 1e18 - liquidityPool.totalAssets();
        assertEq(missingETH, 8.891 ether);
    }
}

contract DepositTestL2 is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(role.owner);
        depositsManagerL2.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL2.deposit(0, 1, 1, address(0));
        vm.stopPrank();
    }

    function test_RevertWhenL1NotApprovedForUsingWETH() external {
        vm.startPrank(role.owner);
        vm.expectRevert(IDepositsManager.InvalidAmount.selector);
        depositsManagerL2.deposit(0, 1, 1, address(0));
        vm.stopPrank();
    }
}

contract DepositETHTestL2 is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(role.owner);
        depositsManagerL2.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL2.depositETH(0, 0, address(0));
        vm.stopPrank();
    }

    function test_RevertWhenNativeTokenNotSupported() external {
        vm.startPrank(role.owner);
        vm.expectRevert(IDepositsManager.NativeTokenNotSupported.selector);
        depositsManagerL2.depositETH(0, 0, address(0));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroETH() external {
        data = abi.encodeWithSignature("initialize(address,address,address,bool)", address(wETHL2), role.owner, role.service, true);
        DepositsManagerL2 depositsManager =
            DepositsManagerL2(payable(proxy.deploy(address(new DepositsManagerL2()), role.admin, data)));

        vm.startPrank(role.owner);
        vm.expectRevert(IDepositsManager.InvalidAmount.selector);
        depositsManager.depositETH(0, 0, address(0));
        vm.stopPrank();
    }
}

contract GetRateL2Test is TestSetup {
    function test_GetRateShouldWorkCorrectly() external {
        assertEq(depositsManagerL2.getRate(), 1 ether);
    }
}

contract SyncTokensTest is TestSetup {
    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(role.owner);
        depositsManagerL2.pause();
        vm.stopPrank();

        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL2.syncTokens(balance);
    }

    function test_RevertWhenNotEnoughWETH() external {
        uint256 balance = wETHL2.balanceOf(address(depositsManagerL2));
        vm.expectRevert(IDepositsManager.InvalidSyncAmount.selector);
        depositsManagerL2.syncTokens(balance);
    }
}

contract OnMessageReceivedL2Test is TestSetup {
    function test_RevertWhenCalledByNonMessenger() external {
        vm.startPrank(bob);
        vm.expectRevert(IDepositsManager.Unauthorized.selector);
        depositsManagerL2.onMessageReceived(1, bytes(""));
        vm.stopPrank();
    }

    function test_RevertWhenCalledByWrongChainId() external {
        vm.startPrank(role.owner);
        depositsManagerL2.setMessenger(address(bob));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(IDepositsManager.Unauthorized.selector);
        depositsManagerL2.onMessageReceived(1000, bytes(""));
        vm.stopPrank();
    }

    function test_RevertWhenPassedInvalidMSG() external {
        vm.startPrank(role.owner);
        depositsManagerL2.setMessenger(address(bob));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(IDepositsManager.InvalidMessageCode.selector);
        depositsManagerL2.onMessageReceived(1, abi.encode(2));
        vm.stopPrank();
    }
}

contract SetTokenL2Test is TestSetup {
    function test_SetTokenShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(address(depositsManagerL2.token()), address(l2token));

        depositsManagerL2.setToken(address(bob));

        assertEq(address(depositsManagerL2.token()), address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenSetTokenCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL2.setToken(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        depositsManagerL2.setToken(address(0));
        vm.stopPrank();
    }
}

contract SetMessengerL2Test is TestSetup {
    function test_SetMessengerShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(address(depositsManagerL2.messenger()), address(messengerL2));
        assertEq(wETHL2.allowance(address(depositsManagerL2), address(messengerL2)), type(uint256).max);
        assertEq(wETHL2.allowance(address(depositsManagerL2), address(bob)), 0);

        depositsManagerL2.setMessenger(address(bob));

        assertEq(address(depositsManagerL2.messenger()), address(bob));
        assertEq(wETHL2.allowance(address(depositsManagerL2), address(messengerL2)), type(uint256).max);
        vm.stopPrank();
    }

    function test_RevertWhenSetMessengerCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositsManagerL2.setMessenger(address(bob));
        vm.stopPrank();
    }

    function test_RevertWhenPassedZeroAddress() external {
        vm.startPrank(role.owner);
        vm.expectRevert(OwnableAccessControl.InvalidAddress.selector);
        depositsManagerL2.setMessenger(address(0));
        vm.stopPrank();
    }
}

contract PauseL2Test is TestSetup {
    function test_PauseShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(depositsManagerL2.paused(), false);
        vm.expectEmit(true, true, true, true, address(depositsManagerL2));
        emit Paused(address(role.owner));
        depositsManagerL2.pause();
        assertEq(depositsManagerL2.paused(), true);
        vm.stopPrank();
    }

    function test_RevertWhenPauseCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControl.UnauthorizedService.selector, bob));
        depositsManagerL2.pause();
        vm.stopPrank();
    }

    function test_RevertWhenAlreadyPaused() external {
        vm.startPrank(role.owner);
        depositsManagerL2.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        depositsManagerL2.pause();
        vm.stopPrank();
    }
}

contract UnpauseL2Test is TestSetup {
    function test_UnpauseShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        depositsManagerL2.pause();
        assertEq(depositsManagerL2.paused(), true);
        vm.expectEmit(true, true, true, true, address(depositsManagerL2));
        emit Unpaused(address(role.owner));
        depositsManagerL2.unpause();
        assertEq(depositsManagerL2.paused(), false);
        vm.stopPrank();
    }

    function test_RevertWhenUnpauseCallerIsNotOwner() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControl.UnauthorizedService.selector, bob));
        depositsManagerL2.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenNotPaused() external {
        vm.startPrank(role.owner);
        vm.expectRevert(bytes("Pausable: not paused"));
        depositsManagerL2.unpause();
        vm.stopPrank();
    }
}
