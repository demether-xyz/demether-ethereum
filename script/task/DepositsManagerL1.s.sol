// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { DepositsManagerL1 } from "../../src/DepositsManagerL1.sol";

contract DepositsManagerL1ConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address doftAddress = vm.envAddress("DOFT_ADDRESS_L1");
        address payable depositsManagerAddress = payable(vm.envAddress("DEPOSITS_MANAGER_L1"));
        address liquidityPoolAddress = vm.envAddress("LIQUIDITY_POOL_L1");
        address messengerAddress = vm.envAddress("MESSENGER_L1");

        DepositsManagerL1 depositsManager = DepositsManagerL1(payable(depositsManagerAddress));

        depositsManager.setToken(doftAddress);
        console.log("setToken called with:", doftAddress);

        depositsManager.setLiquidityPool(liquidityPoolAddress);
        console.log("setLiquidityPool called with:", liquidityPoolAddress);

        depositsManager.setMessenger(messengerAddress);
        console.log("setMessenger called with:", messengerAddress);

        vm.stopBroadcast();
    }
}
