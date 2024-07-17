// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "lib/forge-std/src/console.sol";

import { DOFT } from "../src/DOFT.sol";

contract UpgradableProxy is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address endpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the new implementation contract
        DOFT doftNewImplementation = new DOFT(endpoint);

        // Directly interact with the proxy contract instance to perform the upgrade
        DOFT doftLastImplementationProxy = DOFT(proxyAddress);
        doftLastImplementationProxy.upgradeToAndCall{ value: 0 }(address(doftNewImplementation), "");

        vm.stopBroadcast();
        console.log("Proxy upgraded to new implementation at:", address(doftNewImplementation));
    }
}
