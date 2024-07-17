// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

contract MockStarGate {
    error StarGateInvalidTransferError(uint256 transferAmount, uint256 amountInLocalDecimals);
    error StarGateInvalidSwapError(uint256 swapAmount);
    error StarGateInvalidRefundAddressError(address refundAddress);
    error StarGateInvalidFeeError(uint256 fee);
    error StarGateInvalidSlippageError();
    error EtherTransferError();
    error DecodeAddressError();

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    uint256 public slippage;

    constructor() {
        slippage = 2e15; // 0.2 %;
    }

    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

    // compose stargate to swap ETH on the source to ETH on the destination
    function swapETH(
        uint16, // destination Stargate chainId
        address payable _refundAddress, // refund additional messageFee to this address
        bytes memory _toAddress, // the receiver of the destination ETH
        uint256 _amountLD, // the amount, in Local Decimals, to be swapped
        uint256 _minAmountLD // the minimum amount accepted out on destination
    ) public payable {
        if (msg.value < _amountLD) revert StarGateInvalidTransferError(msg.value, _amountLD);

        // wrap the ETH into WETH
        // IStargateEthVault(stargateEthVault).deposit{value: _amountLD}();
        // IStargateEthVault(stargateEthVault).approve(address(stargateRouter), _amountLD);

        // messageFee is the remainder of the msg.value after wrap
        uint256 messageFee = msg.value - _amountLD;
        if (messageFee < 10 gwei) revert StarGateInvalidFeeError(messageFee);

        // compose a stargate swap() using the WETH that was just wrapped
        if (_amountLD == 0) revert StarGateInvalidSwapError(_amountLD);
        if (_refundAddress == address(0x0)) revert StarGateInvalidRefundAddressError(_refundAddress);

        uint256 feeAmount = (_amountLD * slippage + PRECISION_SUB_ONE) / PRECISION;

        if (_amountLD - feeAmount < _minAmountLD) revert StarGateInvalidSlippageError();

        address toAddress = decodeAddress(_toAddress);
        (bool sent, ) = toAddress.call{ value: _amountLD - feeAmount }("");
        if (!sent) revert EtherTransferError();
    }

    function sendToken(
        SendParam calldata sendParam,
        MessagingFee calldata,
        address refundAddress
    )
        public
        payable
        returns (MessagingReceipt memory messagingReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket)
    {
        swapETH(
            uint16(sendParam.dstEid),
            payable(refundAddress),
            abi.encodePacked(bytes32ToAddress(sendParam.to)),
            sendParam.amountLD,
            sendParam.minAmountLD
        );

        return (messagingReceipt, oftReceipt, ticket);
    }

    function setSlippage(uint256 _slippage) external {
        slippage = _slippage;
    }

    function decodeAddress(bytes memory data) public pure returns (address addr) {
        if (data.length != 0x14) revert DecodeAddressError();
        assembly {
            addr := mload(add(data, 0x14))
        }
    }

    function bytes32ToAddress(bytes32 _bytes) private pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
}
