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

contract OwnableAccessControl is OwnableUpgradeable {
    error UnauthorizedService(address caller);

    address private service;

    event ServiceChanged(address indexed oldService, address indexed newService);

    modifier onlyService() {
        if (msg.sender != service && owner() != _msgSender()) {
            revert UnauthorizedService(msg.sender);
        }
        _;
    }

    function initialize(address admin, address initialService) public initializer {
        __Ownable_init();
        transferOwnership(admin);
        setService(initialService);
    }

    function setService(address newService) public onlyOwner {
        emit ServiceChanged(service, newService);
        service = newService;
    }

    function getService() public view returns (address) {
        return service;
    }
}
