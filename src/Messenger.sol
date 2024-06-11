// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IMessenger.sol";

/**
 * @title Messenger
 * @dev Contracts sends messages and tokens across chains
 */
contract Messenger is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IMessenger
{
    /// @notice Contract able to manage the funds
    address private depositsManager;

    function initialize(
        address _depositsManager,
        address _owner
    ) external initializer onlyProxy {
        if (_depositsManager == address(0)) revert InvalidAddress();

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        transferOwnership(_owner);
    }

    function _authorizeUpgrade(
        address _newImplementation
    ) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert InvalidContract();
    }
}
