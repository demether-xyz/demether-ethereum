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

contract InitializeTest is LiquidityPoolTest {
    function test_RevertWhenAlreadyInitialize() external {
        vm.startPrank(role.owner);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        liquidityPool.initialize(address(0), payable(address(bob)), address(bob));
        vm.stopPrank();
    }

    function test_InitializeProperly() external {
        vm.startPrank(role.owner);
        data = abi.encodeWithSignature("initialize(address,address,address)", address(depositsManagerL1), role.owner, role.service);
        LiquidityPool liquidityPool1 = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), role.admin, data)));
        vm.stopPrank();

        // Verify that the contract is initialized properly
        assertEq(liquidityPool1.owner(), role.owner);
        assertEq(liquidityPool1.protocolTreasury(), role.owner);
        assertEq(liquidityPool1.protocolFee(), 1e17);
    }
}

contract AddLiquidityTest is LiquidityPoolTest {
    function test_RevertWhenAddLiquidityAmountIsInvalid() external {
        vm.deal(address(depositsManagerL1), 1 ether);
        vm.startPrank(address(depositsManagerL1)); // Using the authorized caller
        vm.expectRevert(ILiquidityPool.InvalidAmount.selector);
        liquidityPool.addLiquidity();
        vm.stopPrank();
    }
}

contract TotalAssetsTest is LiquidityPoolTest {
    function test_TotalAssetsShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        uint256 totalAssets = liquidityPool.totalAssets();
        assertEq(totalAssets, 0);
        vm.stopPrank();
    }
}

contract GetRateTest is LiquidityPoolTest {
    function test_GetRateShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        uint256 rate = liquidityPool.getRate();
        assertEq(rate, 1000000000000000000); 
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

    function test_SetFraxMinterShouldWorkCorrectly() external {
        vm.startPrank(role.owner);
        assertEq(address(liquidityPool.fraxMinter()), address(frxETHMinterContract));
        assertEq(address(liquidityPool.sfrxETH()), address(sfrxETHtoken));

          // Deploy frxETH, sfrxETH
        frxETH frxETHtoken1 = new frxETH(role.admin, role.admin);
        sfrxETH sfrxETHtoken1 = new sfrxETH(ERC20_2(address(frxETHtoken1)), 1);

        frxETHMinter frxETHMinterContract1 = new frxETHMinter(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b,
            address(frxETHtoken1),
            address(sfrxETHtoken1),
            role.admin,
            role.admin,
            ""
        );
        liquidityPool.setFraxMinter(address(frxETHMinterContract1));
        assertEq(address(liquidityPool.fraxMinter()), address(frxETHMinterContract1));
        assertEq(address(liquidityPool.sfrxETH()), address(sfrxETHtoken1));
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

    function test_RevertWhenInvalidDelegationManager() external {
        vm.startPrank(role.owner);
        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", address(depositsManagerL1), role.owner, role.service);
        LiquidityPool liquidityPool1 = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), role.admin, data)));

        vm.expectRevert(ILiquidityPool.InvalidEigenLayerStrategy.selector);
        liquidityPool1.delegateEigenLayer(OPERATOR);
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

    function test_RevertWhenLSTMintingNotSet() external {
        vm.startPrank(role.owner);

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", address(depositsManagerL1), role.owner, role.service);
        LiquidityPool liquidityPool1 = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), role.admin, data)));

        vm.expectRevert(ILiquidityPool.LSTMintingNotSet.selector);
        liquidityPool1.setEigenLayer(
            address(eigenLayerContracts.strategyManager),
            address(address(bob)),
            address(eigenLayerContracts.delegation)
        );       
        vm.stopPrank();
    }

    function test_SetEigenLayerShouldWorkCorrectly() external {
        vm.startPrank(role.owner);

        // deploy sfrxETH strategy
        StrategyBase sfrxETHStrategy = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        sfrxETHtoken,
                        eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );
        liquidityPool.setEigenLayer(
            address(address(alice)),
            address(sfrxETHStrategy),
            address(address(charlie))
        );        
       
        assertEq(address(liquidityPool.eigenLayerStrategy()), address(sfrxETHStrategy));
        assertEq(address(liquidityPool.eigenLayerStrategyManager()), address(alice));
        assertEq(address(liquidityPool.eigenLayerDelegationManager()), address(charlie));
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
