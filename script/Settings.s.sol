// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import { Messenger } from "../src/Messenger.sol";
import { IMessenger } from "../src/interfaces/IMessenger.sol";
import { IDOFT } from "../src/interfaces/IDOFT.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

contract Settings is Script {
    using OptionsBuilder for bytes;

    address _messengerL1 = 0x488F2e0603D0856418e544E67E60858537FC005C;
    address _messengerL2 = 0x8d0ac6fD687E7CB8C595F62E93020D3C066ccbb7;
    address _token = 0xbAE3E03e3f847D0adD4eE6bE4732c690f7Fa9cCc;

    function run() public {
        //        _L1_settings_arbitrum();
        // _L2_settings_mainnet();
        _L2_send();
    }

    function _L1_settings_arbitrum() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Address of your deployed contract
        Messenger messengerL1 = Messenger(payable(_messengerL1));

        // Define the parameters for setSettingsMessages
        uint8 LAYERZERO = 1;
        uint32 ARBITRUM = 42161;
        uint32 L2_EID = 30110; // arbitrum
        address messengerL2 = _messengerL2;
        uint128 gas = 200_000;
        bytes memory options = abi.encode(gas);

        console.log(messengerL1.LAYERZERO());

        IMessenger.Settings memory settings = IMessenger.Settings(
            LAYERZERO,
            ARBITRUM,
            L2_EID,
            messengerL2,
            10 gwei, // min fee
            0, // slippage
            options, // gas as uint128
            true // native ETH
        );

        // Call setSettingsMessages
        messengerL1.setSettingsMessages(ARBITRUM, settings);

        vm.stopBroadcast();
    }

    function _L2_settings_check() internal {
        Messenger messengerL2 = Messenger(payable(_messengerL2));
        Origin memory origin = Origin({ srcEid: 30101, sender: addressToBytes32(_messengerL1), nonce: 2 });
        bool allow = messengerL2.allowInitializePath(origin);
        console.log("ALLOW", allow);
    }

    function _L2_send() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IDOFT token = IDOFT(_token);
        address sender = 0x4C0301d076D90468143C2065BBBC78149f1FcAF1;
        uint256 amount = token.balanceOf(sender);
        uint256 _fee = 500_000 gwei;

        // Calculate native fee as LayerZero vanilla OFT send using ~60k wei of native gas
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000 wei, 0);
        SendParam memory sendParam = SendParam(
            30101,
            addressToBytes32(sender),
            amount, // amount is temporary to calculate quote
            amount,
            options,
            "",
            ""
        );
        MessagingFee memory fee = MessagingFee(_fee, 0);

        // send through LayerZero
        // slither-disable-next-line unused-return
        (MessagingReceipt memory receipt, ) = token.send{ value: _fee }(sendParam, fee, payable(sender));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
