// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

contract MockStarGate {
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
        uint16 _dstChainId, // destination Stargate chainId
        address payable _refundAddress, // refund additional messageFee to this address
        bytes memory _toAddress, // the receiver of the destination ETH
        uint256 _amountLD, // the amount, in Local Decimals, to be swapped
        uint256 _minAmountLD // the minimum amount accepted out on destination
    ) public payable {
        require(msg.value > _amountLD, "Stargate: msg.value must be > _amountLD");

        // wrap the ETH into WETH
        // IStargateEthVault(stargateEthVault).deposit{value: _amountLD}();
        // IStargateEthVault(stargateEthVault).approve(address(stargateRouter), _amountLD);

        // messageFee is the remainder of the msg.value after wrap
        uint256 messageFee = msg.value - _amountLD;
        require(messageFee >= 10 gwei, "!fee");

        // compose a stargate swap() using the WETH that was just wrapped
        require(_amountLD > 0, "Stargate: cannot swap 0");
        require(_refundAddress != address(0x0), "Stargate: _refundAddress cannot be 0x0");

        uint256 feeAmount = (_amountLD * slippage + PRECISION_SUB_ONE) / PRECISION;
        require(_amountLD - feeAmount >= _minAmountLD, "!slippage");

        address toAddress = decodeAddress(_toAddress);
        (bool sent, ) = toAddress.call{value: _amountLD - feeAmount}("");
        require(sent, "Failed to send Ether");
    }

    function sendToken(
        SendParam calldata sendParam,
        MessagingFee calldata,
        address refundAddress
    ) public payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket) {
        swapETH(
            uint16(sendParam.dstEid),
            payable(refundAddress),
            abi.encodePacked(bytes32ToAddress(sendParam.to)),
            sendParam.amountLD,
            sendParam.minAmountLD
        );
    }

    function setSlippage(uint256 _slippage) external {
        slippage = _slippage;
    }

    function decodeAddress(bytes memory data) public pure returns (address addr) {
        require(data.length == 0x14);
        assembly {
            addr := mload(add(data, 0x14))
        }
    }

    function bytes32ToAddress(bytes32 _bytes) private pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
}
