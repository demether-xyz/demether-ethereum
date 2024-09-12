// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { console } from "lib/forge-std/src/console.sol";
import { DOFT } from "../../src/DOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DOFTScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        string memory name = "A ETH";
        string memory symbol = "A";
        address initialDelegate = 0x4C0301d076D90468143C2065BBBC78149f1FcAF1;
        address minterAddress = 0x0000000000000000000000000000000000000000;

        DOFT doftImplementation = new DOFT(lzEndpoint);
        ERC1967Proxy doftProxy = new ERC1967Proxy(
            address(doftImplementation),
            abi.encodeWithSelector(DOFT.initialize.selector, name, symbol, initialDelegate, minterAddress)
        );

        DOFT doft = DOFT(address(doftProxy));

        vm.stopBroadcast();
        console.log("DOFT Contract deployed at:", address(doft));
    }
}
