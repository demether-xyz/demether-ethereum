// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DepositsManager} from "./DepositsManager.sol";

/**
 * @title L2 Deposits Manager
 * @dev Base contract for Layer 2
 * Main entry interface allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 */
contract DepositsManagerL2 is DepositsManager {}
