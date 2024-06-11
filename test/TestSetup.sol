// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import "@foundry-upgrades/ProxyTester.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import "./mocks/WETH.sol";
import {DOFT} from "../src/DOFT.sol";
import {DepositsManagerL1} from "../src/DepositsManagerL1.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";

contract TestSetup is Test, TestHelper {
    address internal admin;
    address internal owner;
    ProxyTester internal proxy = new ProxyTester();
    bytes internal data;

    uint32 l1Eid = 1;
    uint32 l2Eid = 2;
    DOFT internal l1token;
    DepositsManagerL1 internal depositsManagerL1;
    WETH public wETHL1;

    function setUp() public virtual override {
        admin = vm.addr(uint256(0x123));
        vm.label(admin, "Admin");

        owner = vm.addr(uint256(0x456));
        vm.label(owner, "Owner");

        // LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        wETHL1 = new WETH();

        // deploy DepositsManagerL2.sol
        data = abi.encodeWithSignature(
            "initialize(address,address,bool)",
            address(wETHL1),
            owner,
            true
        );
        depositsManagerL1 = DepositsManagerL1(
            payable(proxy.deploy(address(new DepositsManagerL1()), admin, data))
        );

        // token
        l1token = new DOFT(
            "",
            "",
            address(endpoints[l1Eid]),
            address(depositsManagerL1)
        );
        vm.label(address(l1token), "l1token");

        // deploy LiquidityPool
        data = abi.encodeWithSignature(
            "initialize(address,address)",
            address(depositsManagerL1),
            owner
        );
        LiquidityPool liquidityPool = LiquidityPool(
            payable(proxy.deploy(address(new LiquidityPool()), admin, data))
        );

        vm.startPrank(owner);
        depositsManagerL1.setToken(address(l1token));
        depositsManagerL1.setLiquidityPool(address(liquidityPool));
        vm.stopPrank();
    }
}
