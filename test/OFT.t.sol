// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam as SendParamUpgradable} from "@layerzerolabs/lz-evm-oapp-v2_upgradable/contracts/oft/interfaces/IOFT.sol";

contract OFTTest is TestSetup {
    using OptionsBuilder for bytes;

    function test_OFT_bridge() public {
        // deposit L1
        depositsManagerL1.depositETH{value: 100 ether}(address(0));
        assertEq(l1token.balanceOf(address(this)), 100 ether);

        // bridge to L2
        uint256 toSend = 10 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(10 gwei, 0);
        SendParamUpgradable memory sendParam = SendParamUpgradable(l2Eid, addressToBytes32(address(this)), toSend, toSend, options, "", "");
        MessagingFee memory fee = l1token.quoteSend(sendParam, false);

        // transfer
        assertEq(l2token.balanceOf(address(this)), 0);
        assertEq(l2token.totalSupply(), 0);

        l1token.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        verifyPackets(l2Eid, addressToBytes32(address(l2token)));

        assertEq(l1token.balanceOf(address(this)), 90 ether);
        assertEq(l2token.balanceOf(address(this)), 10 ether);
    }
}
