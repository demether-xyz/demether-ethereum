// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import { Messenger } from "../src/Messenger.sol";
import { IMessenger } from "../src/interfaces/IMessenger.sol";

contract Settings is Script {
    function run() public {
        _L1_settings_arbitrum();
    }

    function _L1_settings_arbitrum() internal {
        // Address of your deployed contract
        Messenger messengerL1 = Messenger(payable(0x488F2e0603D0856418e544E67E60858537FC005C));

        // Define the parameters for setSettingsMessages
        uint8 LAYERZERO = 1;
        uint32 ARBITRUM = 42161;
        uint32 L2_EID = 30110; // arbitrum
        address messengerL2 = 0x8d0ac6fD687E7CB8C595F62E93020D3C066ccbb7;

        // Encode the value 200_000
        bytes memory encoded = abi.encode(200_000);

        // Print the encoded bytes
        console.log("abi.encode(200_000) as bytes:");
        console.logBytes(encoded);

        IMessenger.Settings memory settings = IMessenger.Settings(
            LAYERZERO,
            ARBITRUM,
            L2_EID,
            messengerL2,
            10 gwei, // min fee
            0, // slippage
            abi.encode(200_000), // gas as uint128
            true // native ETH
        );
    }
}
