// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import { Messenger } from "../src/Messenger.sol";
import { IMessenger } from "../src/interfaces/IMessenger.sol";
import { DepositsManagerL1 } from "../src/DepositsManagerL1.sol";
import { IDOFT } from "../src/interfaces/IDOFT.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

contract Settings is Script {
    using OptionsBuilder for bytes;

    address _depositsL1 = 0xEd58cD5Bf2e00ACeaFeC9e56e972E44f34Bb58c3;
    address _messengerL1 = 0x488F2e0603D0856418e544E67E60858537FC005C;
    address _messengerL2 = 0x8d0ac6fD687E7CB8C595F62E93020D3C066ccbb7;
    address _token_L1 = 0xbAE3E03e3f847D0adD4eE6bE4732c690f7Fa9cCc;
    address _token_L2 = 0xbAE3E03e3f847D0adD4eE6bE4732c690f7Fa9cCc;

    // https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
    // morph 40322

    uint32 L2 = 42161;
    uint32 L2_EID = 30110;
    uint32 L1_EID = 30101;

    function run() public {
        _L1_settings_for_L2();
        //        _token_setPeer();
        //        _token_setPeer_L2();

        //_deposit_to_L2();
        //        _L2_send();
    }

    function _deposit_to_L2() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        DepositsManagerL1 depositsManager = DepositsManagerL1(payable(_depositsL1));
        Messenger messengerL1 = Messenger(payable(_messengerL1));

        uint256 fee = messengerL1.quoteLayerZero(L2) + 100_000 gwei;
        uint256 amount = 0.001 ether;

        // deposit
        depositsManager.depositETH{ value: amount + fee }(L2, fee, address(0));

        vm.stopBroadcast();
    }

    function _L1_settings_for_L2() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Address of your deployed contract
        Messenger messengerL1 = Messenger(payable(_messengerL1));

        // Define the parameters for setSettingsMessages
        uint8 LAYERZERO = 1;
        address messengerL2 = _messengerL2;
        uint128 gas = 200_000;
        bytes memory options = abi.encode(gas);

        console.log(messengerL1.LAYERZERO());

        IMessenger.Settings memory settings = IMessenger.Settings(
            LAYERZERO,
            L2,
            L2_EID,
            _messengerL2,
            10 gwei, // min fee
            0, // slippage
            options, // gas as uint128
            false // native ETH
        );

        // Call setSettingsMessages
        messengerL1.setSettingsMessages(L2, settings);

        vm.stopBroadcast();
    }

    function _token_setPeer() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IDOFT token = IDOFT(_token_L1);
        token.setPeer(L2_EID, addressToBytes32(_token_L2));

        vm.stopBroadcast();
    }

    function _token_setPeer_L2() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IDOFT token = IDOFT(_token_L2);
        token.setPeer(L1_EID, addressToBytes32(_token_L1));

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

        IDOFT token = IDOFT(_token_L1);
        address sender = 0x4C0301d076D90468143C2065BBBC78149f1FcAF1;
        uint256 amount = 1000 gwei;
        uint256 amount_out = _removeDust(amount);
        uint256 _fee = 500_000 gwei;
        require(amount_out > 0, "Amount out is zero");

        // Calculate native fee as LayerZero vanilla OFT send using ~60k wei of native gas
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000 wei, 0);
        SendParam memory sendParam = SendParam(L2_EID, addressToBytes32(sender), amount, amount_out, options, "", "");
        MessagingFee memory fee = MessagingFee(_fee, 0);

        // send through LayerZero
        // slither-disable-next-line unused-return
        (MessagingReceipt memory receipt, ) = token.send{ value: _fee }(sendParam, fee, payable(sender));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function _removeDust(uint256 _amountLD) internal view returns (uint256 amountLD) {
        IDOFT token = IDOFT(_token_L1);
        uint256 decimalConversionRate = token.decimalConversionRate();
        // slither-disable-next-line divide-before-multiply
        return (_amountLD / decimalConversionRate) * decimalConversionRate;
    }
}
