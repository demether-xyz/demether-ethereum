// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICurvePool {
    function get_p() external view returns (uint256);
}
