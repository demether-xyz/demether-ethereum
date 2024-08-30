// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { DepositsManagerL1 } from "../../src/DepositsManagerL1.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DepositsManagerL1DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = 0xB75D71adFc8E5F7c58eA89c22C3B70BEA84A718d;
        address service = 0x46E075FDd18bec99e701F54C38219F2b20065114;

        DepositsManagerL1 depositsManagerImplementation = new DepositsManagerL1();
        ERC1967Proxy depositsManagerProxy = new ERC1967Proxy(
            address(depositsManagerImplementation),
            abi.encodeWithSelector(DepositsManagerL1.initialize.selector, owner, service)
        );
        DepositsManagerL1 depositsManager = DepositsManagerL1(payable(address(depositsManagerProxy)));

        vm.stopBroadcast();
        console.log("DepositsManagerL1 Implementation deployed at:", address(depositsManagerImplementation));
        console.log("DepositsManagerL1 Proxy deployed at:", address(depositsManagerProxy));
    }
}
