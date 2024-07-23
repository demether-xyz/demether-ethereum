// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockCurvePool {
    uint256 public constant FIXED_RATE = 1 ether;

    function get_p() external pure returns (uint256) {
        return FIXED_RATE;
    }
}
