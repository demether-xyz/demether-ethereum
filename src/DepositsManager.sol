// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title L2 Deposits Manager
 * @dev Base contract for Layer 2
 * Main entry interface allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 */
contract DepositsManager is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    function initialize(
    ) external initializer onlyProxy {
        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
