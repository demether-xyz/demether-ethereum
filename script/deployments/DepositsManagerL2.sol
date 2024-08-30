// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { DepositsManagerL2 } from "../../src/DepositsManagerL2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DepositsManagerL2DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address wETH = 0xc556bAe1e86B2aE9c22eA5E036b07E55E7596074;
        address owner = 0x46E075FDd18bec99e701F54C38219F2b20065114;
        address service = 0x46E075FDd18bec99e701F54C38219F2b20065114;
        bool nativeSupport = true;

        DepositsManagerL2 depositsManagerImplementation = new DepositsManagerL2();
        ERC1967Proxy depositsManagerProxy = new ERC1967Proxy(
            address(depositsManagerImplementation),
            abi.encodeWithSelector(DepositsManagerL2.initialize.selector, wETH, owner, service, nativeSupport)
        );
        DepositsManagerL2 depositsManager = DepositsManagerL2(address(depositsManagerProxy));

        vm.stopBroadcast();
        console.log("DepositsManagerL2 Implementation deployed at:", address(depositsManagerImplementation));
        console.log("DepositsManagerL2 Proxy deployed at:", address(depositsManagerProxy));
    }
}
