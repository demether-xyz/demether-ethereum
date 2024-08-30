// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { DepositsManagerL2 } from "../../src/DepositsManagerL2.sol";

contract DepositsManagerL2ConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address doftAddress = vm.envAddress("DOFT_ADDRESS_L2");
        address payable depositsManagerAddress = payable(vm.envAddress("DEPOSITS_MANAGER_L2"));
        address messengerAddress = vm.envAddress("MESSENGER_L2");

        uint256 depositFee = 1e15; // Example: 0.1% fee (in 1e18 precision)
        uint256 maxRateStaleness = 3 days; // Equivalent to 259200 seconds (3 days)

        DepositsManagerL2 depositsManagerL2 = DepositsManagerL2(payable(depositsManagerAddress));

        depositsManagerL2.setDepositFee(depositFee);
        console.log("setDepositFee called with:", depositFee);

        depositsManagerL2.setMaxRateStaleness(maxRateStaleness);
        console.log("setMaxRateStaleness called with:", maxRateStaleness);

        depositsManagerL2.setToken(doftAddress);
        console.log("setToken called with:", doftAddress);

        depositsManagerL2.setMessenger(messengerAddress);
        console.log("setMessenger called with:", messengerAddress);

        vm.stopBroadcast();
    }
}
