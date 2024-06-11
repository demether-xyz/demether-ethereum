// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DepositsManager} from "./DepositsManager.sol";

/**
 * @title L1 Deposits Manager
 * @dev Base contract for Layer 1
 * Main entry interface allows users to deposit tokens on Layer 1
 */
contract DepositsManagerL1 is DepositsManager {}
