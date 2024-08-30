// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { LiquidityPool } from "../../src/LiquidityPool.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LiquidityPoolDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address depositsManagerL2 = vm.envAddress("DEPOSITS_MANAGER_L2");

        address payable owner = payable(0xB75D71adFc8E5F7c58eA89c22C3B70BEA84A718d);
        address service = 0x46E075FDd18bec99e701F54C38219F2b20065114;

        LiquidityPool liquidityPoolImplementation = new LiquidityPool();

        ERC1967Proxy liquidityPoolProxy = new ERC1967Proxy(
            address(liquidityPoolImplementation),
            abi.encodeWithSelector(LiquidityPool.initialize.selector, depositsManagerL2, owner, service)
        );

        LiquidityPool liquidityPool = LiquidityPool(address(liquidityPoolProxy));

        vm.stopBroadcast();
        console.log("LiquidityPool Implementation deployed at:", address(liquidityPoolImplementation));
        console.log("LiquidityPool Proxy deployed at:", address(liquidityPoolProxy));
    }
}
