// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// *******************************************************
// *    ____                      _   _                  *
// *   |  _ \  ___ _ __ ___   ___| |_| |__   ___ _ __    *
// *   | | | |/ _ \ '_ ` _ \ / _ \ __| '_ \ / _ \ '__|   *
// *   | |_| |  __/ | | | | |  __/ |_| | | |  __/ |      *
// *   |____/ \___|_| |_| |_|\___|\__|_| |_|\___|_|      *
// *******************************************************
// Demether Finance: https://github.com/demetherdefi

// Primary Author(s)
// Juan C. Dorado: https://github.com/jdorado/

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title OwnableAccessControl
/// @notice Extends OwnableUpgradeable with additional service role functionality
abstract contract OwnableAccessControl is OwnableUpgradeable {
    /// @notice Thrown when an unauthorized address attempts a service-only operation
    /// @param caller The address that attempted the call
    error UnauthorizedService(address caller);

    /// @notice Thrown when an invalid (zero) address is provided
    error InvalidAddress();

    /// @notice Address of the service role
    address private service;

    /// @notice Emitted when the service address is changed
    /// @param oldService The previous service address
    /// @param newService The new service address
    event ServiceChanged(address indexed oldService, address indexed newService);

    /// @notice Restricts function access to the owner or the service address
    modifier onlyService() {
        if (msg.sender != service && owner() != _msgSender()) {
            revert UnauthorizedService(msg.sender);
        }
        _;
    }

    /// @notice Initializes the contract, setting the admin and initial service address
    /// @param admin The address to be set as the owner
    /// @param initialService The initial service address
    // solhint-disable-next-line
    function __OwnableAccessControl_init(address admin, address initialService) public onlyInitializing {
        __Ownable_init();
        setService(initialService);
        transferOwnership(admin);
    }

    /// @notice Sets a new service address
    /// @param _newService The new service address to be set
    function setService(address _newService) public onlyOwner {
        if (_newService == address(0)) revert InvalidAddress();
        emit ServiceChanged(service, _newService);
        service = _newService;
    }

    /// @notice Retrieves the current service address
    /// @return The current service address
    function getService() public view returns (address) {
        return service;
    }
}
