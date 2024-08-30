// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { Messenger } from "../../src/Messenger.sol";

contract MessengerConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address messengerAddress = vm.envAddress("MESSENGER_L2");

        Messenger messenger = Messenger(messengerAddress);

        uint32 destChainIdMessages = 10001; // Example destination chain ID
        Messenger.Settings memory settingsMessages = Messenger.Settings({
            bridgeId: 1, // Replace with the actual bridge ID (e.g., LayerZero, Stargate)
            chainId: 1, // Replace with Destination chain ID
            bridgeChainId: 10001, // Replace with the actual chain ID used by the brige protocol
            toAddress: "", // Replace with the address where the messages will be sent
            minFee: 10000000000000000, // Example minimum fee (in wei)
            maxSlippage: 50000000000000000, // Example max slippage (in 1e18 precision)
            options: "", // Any additional options if necessary
            nativeTransfer: false // Set true if native transfer is allowed
        });

        // Call setSettingsMessages
        messenger.setSettingsMessages(destChainIdMessages, settingsMessages);
        console.log("setSettingsMessages called for destination chain:", destChainIdMessages);

        // Define the parameters for setSettingsTokens
        uint32 destChainIdTokens = 10001; // Example destination chain ID
        Messenger.Settings memory settingsTokens = Messenger.Settings({
            bridgeId: 2, // Replace with the actual bridge ID (e.g., LayerZero, Stargate)
            chainId: 1, // Replace with Destination chain ID
            bridgeChainId: 10001, // Replace with the actual chain ID used by the brige protocol
            toAddress: "", // Replace with the address where the tokens will be sent
            minFee: 10000000000000000, // Example minimum fee (in wei)
            maxSlippage: 50000000000000000, // Example max slippage (in 1e18 precision)
            options: "", // Any additional options if necessary
            nativeTransfer: true // Set true if native transfer is allowed
        });

        // Call setSettingsTokens
        messenger.setSettingsTokens(destChainIdTokens, settingsTokens);
        console.log("setSettingsTokens called for destination chain:", destChainIdTokens);

        uint8[] memory bridgeIds = [1, 2];

        address[2] memory routers;
        routers[0] = "";
        routers[1] = "";

        address ownerAddress = "";

        messenger.setRouters(bridgeIds, routers, ownerAddress);
        console.log("setRouters called with bridge IDs:", bridgeIds);

        vm.stopBroadcast();
    }
}
