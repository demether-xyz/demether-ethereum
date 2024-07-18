// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {TestSetupEigenLayer, StrategyBase, TransparentUpgradeableProxy, IStrategy, IDelegationManager} from "./TestSetupEigenLayer.sol";
import "@foundry-upgrades/ProxyTester.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {frxETH} from "@frxETH/frxETH.sol";
import {sfrxETH, ERC20 as ERC20_2} from "@frxETH/sfrxETH.sol";
import {frxETHMinter} from "@frxETH/frxETHMinter.sol";

import {DOFT} from "../src/DOFT.sol";
import {DepositsManagerL1} from "../src/DepositsManagerL1.sol";
import {DepositsManagerL2, IMessenger} from "../src/DepositsManagerL2.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {Messenger} from "../src/Messenger.sol";

import "./mocks/WETH.sol";
import "./mocks/MockStarGate.sol";

contract TestSetup is Test, TestHelper, TestSetupEigenLayer {
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_v2 = 3;

    address internal admin;
    address internal owner;
    address internal service;
    ProxyTester internal proxy = new ProxyTester();
    bytes internal data;

    uint32 l1Eid = 1;
    uint32 l2Eid = 2;
    DOFT internal l1token;
    DOFT internal l2token;

    DepositsManagerL1 internal depositsManagerL1;
    DepositsManagerL2 internal depositsManagerL2;
    Messenger internal messengerL1;
    Messenger internal messengerL2;
    LiquidityPool internal liquidityPool;

    WETH public wETHL1;
    WETH public wETHL2;

    MockStarGate public stargateL2;
    sfrxETH public sfrxETHtoken;
    frxETHMinter public frxETHMinterContract;

    function _setUp_L1() public {
        // LayerZero endpoints
        setUpEndpoints(2, LibraryType.SimpleMessageLib);

        // Deploy frxETH, sfrxETH
        frxETH frxETHtoken = new frxETH(admin, admin);
        sfrxETHtoken = new sfrxETH(ERC20_2(address(frxETHtoken)), 1);
        frxETHMinterContract = new frxETHMinter(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b,
            address(frxETHtoken),
            address(sfrxETHtoken),
            admin,
            admin,
            ""
        );
        vm.prank(admin);
        frxETHtoken.addMinter(address(frxETHMinterContract));

        // increase sfrxETHtoken rate to 2.0
        frxETHMinterContract.submitAndDeposit{value: 1 ether}(address(this));
        frxETHMinterContract.submitAndGive{value: 1 ether}(address(sfrxETHtoken));
        vm.warp(block.timestamp + 1);
        sfrxETHtoken.syncRewards();
        vm.warp(block.timestamp + 1);

        // set-up WETH
        wETHL1 = new WETH();

        // deploy DepositsManagerL1.sol
        data = abi.encodeWithSignature("initialize(address,address,address,bool)", address(wETHL1), owner, service, true);
        depositsManagerL1 = DepositsManagerL1(payable(proxy.deploy(address(new DepositsManagerL1()), admin, data)));
        vm.label(address(depositsManagerL1), "depositsManagerL1");

        // token
        data = abi.encodeWithSignature(
            "initialize(string,string,address,address)",
            "Token Name",
            "Token Symbol",
            owner,
            address(depositsManagerL1)
        );
        l1token = DOFT(payable(proxy.deploy(address(new DOFT(address(endpoints[l1Eid]))), admin, data)));
        vm.label(address(l1token), "l1token");

        // deploy LiquidityPool
        data = abi.encodeWithSignature("initialize(address,address,address)", address(depositsManagerL1), owner, service);
        liquidityPool = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), admin, data)));
        vm.label(address(liquidityPool), "liquidityPool");

        // deploy Messenger
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            address(wETHL1),
            address(depositsManagerL1),
            owner,
            service
        );
        messengerL1 = Messenger(payable(proxy.deploy(address(new Messenger()), admin, data)));
        vm.label(address(messengerL1), "messengerL1");
    }

    function _setUp_L2() public {
        wETHL2 = new WETH();
        stargateL2 = new MockStarGate();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature("initialize(address,address,address,bool)", address(wETHL2), owner, service, false);
        depositsManagerL2 = DepositsManagerL2(payable(proxy.deploy(address(new DepositsManagerL2()), admin, data)));
        vm.label(address(depositsManagerL2), "depositsManagerL2");

        // deploy token
        data = abi.encodeWithSignature(
            "initialize(string,string,address,address)",
            "Token Name",
            "Token Symbol",
            owner,
            address(depositsManagerL2)
        );
        l2token = DOFT(payable(proxy.deploy(address(new DOFT(address(endpoints[l2Eid]))), admin, data)));
        vm.label(address(l2token), "l2token");

        // deploy Messenger
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            address(wETHL2),
            address(depositsManagerL2),
            owner,
            service
        );
        messengerL2 = Messenger(payable(proxy.deploy(address(new Messenger()), admin, data)));
        vm.label(address(messengerL2), "messengerL2");
    }

    function _settings() public {
        vm.startPrank(owner);

        // L1
        depositsManagerL1.setToken(address(l1token));
        depositsManagerL1.setLiquidityPool(address(liquidityPool));
        depositsManagerL1.setMessenger(address(messengerL1));
        liquidityPool.setFraxMinter(address(frxETHMinterContract));

        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);
        _bridgeIds[0] = LAYERZERO;
        _routers[0] = endpoints[l1Eid];
        messengerL1.setRouters(_bridgeIds, _routers, owner);

        // LayerZero for messages
        messengerL1.setSettingsMessages(
            l2Eid,
            IMessenger.Settings(
                LAYERZERO,
                l2Eid,
                l2Eid,
                address(messengerL2),
                10 gwei,
                0,
                abi.encode(200_000) // gas as uint128
            )
        );

        // L2
        depositsManagerL2.setToken(address(l2token));
        depositsManagerL2.setMessenger(address(messengerL2));
        depositsManagerL2.setDepositFee(1e15); // 0.1%

        _bridgeIds = new uint8[](2);
        _routers = new address[](2);
        _bridgeIds[0] = LAYERZERO;
        _bridgeIds[1] = STARGATE;
        _routers[0] = endpoints[l2Eid];
        _routers[1] = address(stargateL2);
        messengerL2.setRouters(_bridgeIds, _routers, owner);

        // LayerZero for messages
        messengerL2.setSettingsMessages(
            l1Eid,
            IMessenger.Settings(
                LAYERZERO,
                l1Eid,
                l1Eid,
                address(messengerL1),
                10 gwei,
                0,
                abi.encode(200_000) // gas as uint128
            )
        );

        // StarGate for tokens >> 0.25% allowed slippage / effective is 0.20% on mock
        messengerL2.setSettingsTokens(l1Eid, IMessenger.Settings(STARGATE, l1Eid, l1Eid, address(depositsManagerL1), 10 gwei, 25e14, ""));

        // set token peers >> test L1 to L2 transfers
        l1token.setPeer(l2Eid, addressToBytes32(address(l2token)));
        l2token.setPeer(l1Eid, addressToBytes32(address(l1token)));

        vm.stopPrank();
    }

    function _setUp_EigenLayer() public {
        TestSetupEigenLayer.setUp();

        // deploy sfrxETH strategy
        StrategyBase sfrxETHStrategy = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(baseStrategyImplementation),
                    address(eigenLayerProxyAdmin),
                    abi.encodeWithSelector(StrategyBase.initialize.selector, sfrxETHtoken, eigenLayerPauserReg)
                )
            )
        );

        // whitelist strategy
        IStrategy[] memory _strategy = new IStrategy[](1);
        bool[] memory _thirdPartyTransfersForbiddenValues = new bool[](1);
        _strategy[0] = sfrxETHStrategy;
        vm.prank(strategyManager.strategyWhitelister());
        strategyManager.addStrategiesToDepositWhitelist(_strategy, _thirdPartyTransfersForbiddenValues);

        // register operator
        vm.startPrank(operator);
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            __deprecated_earningsReceiver: address(0),
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        string memory emptyStringForMetadataURI;
        delegation.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        vm.stopPrank();

        // set-up EigenLayer
        vm.prank(owner);
        liquidityPool.setEigenLayer(address(strategyManager), address(sfrxETHStrategy), address(delegation));
    }

    function setUp() public virtual override(TestSetupEigenLayer, TestHelper) {
        admin = vm.addr(uint256(0x123));
        vm.label(admin, "Admin");

        owner = vm.addr(uint256(0x456));
        vm.label(owner, "Owner");

        service = vm.addr(uint256(0x789));
        vm.label(owner, "Service");

        _setUp_L1();
        _setUp_L2();
        _settings();
        _sync_rate();
        _setUp_EigenLayer();
    }

    /// @dev LayerZero syncing
    function _sync() internal {
        // destination L1
        // verifyPackets(l1Eid, addressToBytes32(address(messengerL1)));

        // destination L2
        verifyPackets(l2Eid, addressToBytes32(address(messengerL2)));
    }

    function _sync_rate() internal {
        uint32[] memory _chainId = new uint32[](1);
        uint256[] memory _chainFee = new uint256[](1);
        uint256 fee = 10 gwei;
        _chainId[0] = l2Eid;
        _chainFee[0] = fee;
        vm.roll(block.number + 1);
        depositsManagerL1.syncRate{value: fee}(_chainId, _chainFee);
        _sync();
    }

    function _rewards(uint256 amount) internal {
        address pool = address(depositsManagerL1.pool());
        vm.deal(pool, pool.balance + amount);
    }
}
