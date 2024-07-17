// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "lib/forge-std/src/Script.sol";
import { DOFT } from "../src/DOFT.sol";

import { ERC1967Proxy } from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDOFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address endpoint = vm.envAddress("LAYER_ZERO_ENDPOINT"); // LZ endpoint address from environment variables
        address owner = vm.envAddress("OWNER"); // Owner address from environment variables
        string memory name = vm.envString("TOKEN_NAME"); // Token name from environment variables
        string memory symbol = vm.envString("TOKEN_SYMBOL"); // Token symbol from environment variables

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        DOFT doftImplementation = new DOFT(endpoint);

        // Encode the initialization call
        bytes memory data = abi.encodeWithSelector(DOFT.initialize.selector, name, symbol, owner);

        // Deploy the proxy contract pointing to the implementation
        new ERC1967Proxy(address(doftImplementation), data);

        vm.stopBroadcast();
    }
}
