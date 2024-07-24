// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {TestSetupEigenLayer, StrategyBase, TransparentUpgradeableProxy, StrategyManager} from "./TestSetupEigenLayer.sol";
import {ProxyTester} from "@foundry-upgrades/ProxyTester.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {frxETH} from "@frxETH/frxETH.sol";
import {sfrxETH, ERC20 as ERC20_2} from "@frxETH/sfrxETH.sol";
import {frxETHMinter} from "@frxETH/frxETHMinter.sol";
import {DOFT} from "../src/DOFT.sol";
import {DepositsManagerL1} from "../src/DepositsManagerL1.sol";
import {DepositsManagerL2, IMessenger} from "../src/DepositsManagerL2.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {Messenger} from "../src/Messenger.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";

import {WETH} from "./mocks/WETH.sol";
import {MockStarGate} from "./mocks/MockStarGate.sol";

contract TestSetup is Test, TestHelper, TestSetupEigenLayer {
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_V2 = 3;
    uint32 public constant L1_EID = 1;
    uint32 public constant L2_EID = 2;

    struct Role {
        address admin;
        address owner;
        address service;
    }

    Role internal role;

    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");
    address public charlie = makeAddr("charlie");

    ProxyTester internal proxy = new ProxyTester();
    bytes internal data;
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

    function setUpL1() public {
        // LayerZero endpoints
        setUpEndpoints(2, LibraryType.SimpleMessageLib);

        // Deploy frxETH, sfrxETH
        frxETH frxETHtoken = new frxETH(role.admin, role.admin);
        sfrxETHtoken = new sfrxETH(ERC20_2(address(frxETHtoken)), 1);
        frxETHMinterContract = new frxETHMinter(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b,
            address(frxETHtoken),
            address(sfrxETHtoken),
            role.admin,
            role.admin,
            ""
        );
        vm.prank(role.admin);
        frxETHtoken.addMinter(address(frxETHMinterContract));

        // increase sfrxETHtoken rate to 2.0
        frxETHMinterContract.submitAndDeposit{ value: 1 ether }(address(this));
        frxETHMinterContract.submitAndGive{ value: 1 ether }(address(sfrxETHtoken));
        vm.warp(block.timestamp + 1);
        sfrxETHtoken.syncRewards();
        vm.warp(block.timestamp + 1);

        // set-up WETH
        wETHL1 = new WETH();

        // deploy DepositsManagerL1.sol
        data = abi.encodeWithSignature("initialize(address,address)", role.owner, role.service);
        depositsManagerL1 = DepositsManagerL1(payable(proxy.deploy(address(new DepositsManagerL1()), role.admin, data)));
        vm.label(address(depositsManagerL1), "depositsManagerL1");

        // token
        data = abi.encodeWithSignature(
            "initialize(string,string,address,address)",
            "Token Name",
            "Token Symbol",
            role.owner,
            address(depositsManagerL1)
        );
        l1token = DOFT(payable(proxy.deploy(address(new DOFT(address(endpoints[L1_EID]))), role.admin, data)));
        vm.label(address(l1token), "l1token");

        // deploy LiquidityPool
        data = abi.encodeWithSignature("initialize(address,address,address)", address(depositsManagerL1), role.owner, role.service);
        liquidityPool = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), role.admin, data)));
        vm.label(address(liquidityPool), "liquidityPool");

        // deploy Messenger
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address)", address(wETHL1), address(depositsManagerL1), role.owner, role.service
        );
        messengerL1 = Messenger(payable(proxy.deploy(address(new Messenger()), role.admin, data)));
        vm.label(address(messengerL1), "messengerL1");
    }

    function setUpL2() public {
        wETHL2 = new WETH();
        stargateL2 = new MockStarGate();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature("initialize(address,address,address,bool)", address(wETHL2), role.owner, role.service, false);
        depositsManagerL2 = DepositsManagerL2(payable(proxy.deploy(address(new DepositsManagerL2()), role.admin, data)));
        vm.label(address(depositsManagerL2), "depositsManagerL2");

        // deploy token
        data = abi.encodeWithSignature(
            "initialize(string,string,address,address)",
            "Token Name",
            "Token Symbol",
            role.owner,
            address(depositsManagerL2)
        );
        l2token = DOFT(payable(proxy.deploy(address(new DOFT(address(endpoints[L2_EID]))), role.admin, data)));
        vm.label(address(l2token), "l2token");

        // deploy Messenger
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address)", address(wETHL2), address(depositsManagerL2), role.owner, role.service
        );
        messengerL2 = Messenger(payable(proxy.deploy(address(new Messenger()), role.admin, data)));
        vm.label(address(messengerL2), "messengerL2");
    }

    function settings() public {
        vm.startPrank(role.owner);

        // L1
        depositsManagerL1.setToken(address(l1token));
        depositsManagerL1.setLiquidityPool(address(liquidityPool));
        depositsManagerL1.setMessenger(address(messengerL1));
        liquidityPool.setFraxMinter(address(frxETHMinterContract));

        uint8[] memory _bridgeIds = new uint8[](1);
        address[] memory _routers = new address[](1);
        _bridgeIds[0] = LAYERZERO;
        _routers[0] = endpoints[L1_EID];
        messengerL1.setRouters(_bridgeIds, _routers, role.owner);

        // LayerZero for messages
        messengerL1.setSettingsMessages(
            L2_EID,
            IMessenger.Settings(
                LAYERZERO,
                L2_EID,
                L2_EID,
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
        _routers[0] = endpoints[L2_EID];
        _routers[1] = address(stargateL2);
        messengerL2.setRouters(_bridgeIds, _routers, role.owner);

        // LayerZero for messages
        messengerL2.setSettingsMessages(
            L1_EID,
            IMessenger.Settings(
                LAYERZERO,
                L1_EID,
                L1_EID,
                address(messengerL1),
                10 gwei,
                0,
                abi.encode(200_000) // gas as uint128
            )
        );

        // StarGate for tokens >> 0.25% allowed slippage / effective is 0.20% on mock
        messengerL2.setSettingsTokens(
            L1_EID, IMessenger.Settings(STARGATE, L1_EID, L1_EID, address(depositsManagerL1), 10 gwei, 25e14, "")
        );

        // set token peers >> test L1 to L2 transfers
        l1token.setPeer(L2_EID, addressToBytes32(address(l2token)));
        l2token.setPeer(L1_EID, addressToBytes32(address(l1token)));

        vm.stopPrank();
    }

    function setupEigenLayer() public {
        TestSetupEigenLayer.setUp();

        // deploy sfrxETH strategy
        StrategyBase sfrxETHStrategy = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector, sfrxETHtoken, eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );

        // whitelist strategy
        IStrategy[] memory _strategy = new IStrategy[](1);
        bool[] memory _thirdPartyTransfersForbiddenValues = new bool[](1);
        _strategy[0] = sfrxETHStrategy;
        vm.prank(eigenLayerContracts.strategyManager.strategyWhitelister());
        eigenLayerContracts.strategyManager.addStrategiesToDepositWhitelist(_strategy, _thirdPartyTransfersForbiddenValues);

        // register operator
        vm.startPrank(OPERATOR);
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            __deprecated_earningsReceiver: address(0),
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        string memory emptyStringForMetadataURI;
        eigenLayerContracts.delegation.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        vm.stopPrank();

        // set-up EigenLayer
        vm.prank(role.owner);
        liquidityPool.setEigenLayer(
            address(eigenLayerContracts.strategyManager),
            address(sfrxETHStrategy),
            address(eigenLayerContracts.delegation)
        );
    }

    function setUp() public virtual override(TestSetupEigenLayer, TestHelper) {
        role.admin = vm.addr(uint256(0x123));
        vm.label(role.admin, "Admin");

        role.owner = vm.addr(uint256(0x456));
        vm.label(role.owner, "Owner");

        role.service = vm.addr(uint256(0x789));
        vm.label(role.service, "Service");

        setUpL1();
        setUpL2();
        settings();
        syncRate();
        setupEigenLayer();
    }

    /// @dev LayerZero syncing
    function sync() internal {
        // destination L1
        // verifyPackets(L1_EID, addressToBytes32(address(messengerL1)));

        // destination L2
        verifyPackets(L2_EID, addressToBytes32(address(messengerL2)));
    }

    function syncRate() internal {
        uint32[] memory _chainId = new uint32[](1);
        uint256[] memory _chainFee = new uint256[](1);
        uint256 fee = 10 gwei;
        _chainId[0] = L2_EID;
        _chainFee[0] = fee;
        vm.roll(block.number + 1);
        depositsManagerL1.syncRate{value: fee}(_chainId, _chainFee);
        sync();
    }

    function _rewards(uint256 amount) internal {
        address pool = address(depositsManagerL1.pool());
        vm.deal(pool, pool.balance + amount);
    }
}
