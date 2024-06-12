// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import "@foundry-upgrades/ProxyTester.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {DOFT} from "../src/DOFT.sol";
import {DepositsManagerL1} from "../src/DepositsManagerL1.sol";
import {DepositsManagerL2, IMessenger} from "../src/DepositsManagerL2.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {Messenger} from "../src/Messenger.sol";
import "./mocks/WETH.sol";
import "./mocks/StarGateMock.sol";

contract TestSetup is Test, TestHelper {
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_v2 = 3;

    address internal admin;
    address internal owner;
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

    StarGateMock stargateL2;

    function _setUp_L1() public {
        // LayerZero endpoints
        setUpEndpoints(2, LibraryType.SimpleMessageLib);

        wETHL1 = new WETH();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL1), owner, true);
        depositsManagerL1 = DepositsManagerL1(payable(proxy.deploy(address(new DepositsManagerL1()), admin, data)));
        vm.label(address(depositsManagerL1), "depositsManagerL1");

        // token
        l1token = new DOFT("", "", address(endpoints[l1Eid]), address(depositsManagerL1));
        vm.label(address(l1token), "l1token");

        // deploy LiquidityPool
        data = abi.encodeWithSignature("initialize(address,address)", address(depositsManagerL1), owner);
        liquidityPool = LiquidityPool(payable(proxy.deploy(address(new LiquidityPool()), admin, data)));

        // deploy Messenger
        data = abi.encodeWithSignature("initialize(address,address,address)", address(wETHL1), address(depositsManagerL1), owner);
        messengerL1 = Messenger(payable(proxy.deploy(address(new Messenger()), admin, data)));
        vm.label(address(messengerL1), "messengerL1");
    }

    function _setUp_L2() public {
        wETHL2 = new WETH();
        stargateL2 = new StarGateMock();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature("initialize(address,address,bool)", address(wETHL2), owner, false);
        depositsManagerL2 = DepositsManagerL2(payable(proxy.deploy(address(new DepositsManagerL2()), admin, data)));
        vm.label(address(depositsManagerL2), "depositsManagerL2");

        // deploy token
        l2token = new DOFT("", "", address(endpoints[l2Eid]), address(depositsManagerL2));
        vm.label(address(l2token), "l2token");

        // deploy Messenger
        data = abi.encodeWithSignature("initialize(address,address,address)", address(wETHL2), address(depositsManagerL2), owner);
        messengerL2 = Messenger(payable(proxy.deploy(address(new Messenger()), admin, data)));
        vm.label(address(messengerL2), "messengerL2");
    }

    function _settings() public {
        vm.startPrank(owner);

        // L1
        depositsManagerL1.setToken(address(l1token));
        depositsManagerL1.setLiquidityPool(address(liquidityPool));
        depositsManagerL1.setMessenger(address(messengerL1));

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

        // StarGate for tokens
        messengerL2.setSettingsTokens(l1Eid, IMessenger.Settings(STARGATE, l1Eid, l1Eid, address(depositsManagerL1), 10 gwei, 1e15, ""));

        // todo set token peers >> test L1 to L2 transfers
        vm.stopPrank();
    }

    function setUp() public virtual override {
        admin = vm.addr(uint256(0x123));
        vm.label(admin, "Admin");

        owner = vm.addr(uint256(0x456));
        vm.label(owner, "Owner");

        _setUp_L1();
        _setUp_L2();
        _settings();
    }

    /// @dev LayerZero syncing
    function _sync() internal {
        // destination L1
        // verifyPackets(l1Eid, addressToBytes32(address(messengerL1)));

        // destination L2
        verifyPackets(l2Eid, addressToBytes32(address(messengerL2)));
    }
}
