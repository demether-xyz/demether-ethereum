// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { Messenger } from "../../src/Messenger.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MessengerDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address depositsManagerL1 = vm.envAddress("DEPOSITS_MANAGER_L1");

        address wETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
        address owner = 0xB75D71adFc8E5F7c58eA89c22C3B70BEA84A718d;
        address service = 0x46E075FDd18bec99e701F54C38219F2b20065114;

        Messenger messengerImplementation = new Messenger();
        ERC1967Proxy messengerProxy = new ERC1967Proxy(
            address(messengerImplementation),
            abi.encodeWithSelector(Messenger.initialize.selector, wETH, depositsManagerL1, owner, service)
        );
        Messenger messenger = Messenger(payable(address(messengerProxy)));

        vm.stopBroadcast();
        console.log("Messenger Implementation deployed at:", address(messengerImplementation));
        console.log("Messenger Proxy deployed at:", address(messengerProxy));
    }
}
