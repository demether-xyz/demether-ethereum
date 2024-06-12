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

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/ILiquidityPool.sol";

/**
 * @title LiquidityPool
 * @dev Contracts holds ETH and determines the global rate
 */
contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    error InvalidAmount();
    error InvalidCaller();

    event AddLiquidity(uint256 amount, uint256 shares, uint256 totalAmount, uint256 totalShares);

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Amount of total shares issued
    uint256 public shares;

    function initialize(address _depositsManager, address _owner) external initializer onlyProxy {
        require(_depositsManager != address(0), "_depositsManager address");

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        transferOwnership(_owner);
    }

    /// @notice Received ETH and mints shares to determine rate
    function addLiquidity() external payable {
        // TODO confirm we need it in ETH and not WETH depending on the strategies
        if (msg.sender != depositsManager) revert InvalidCaller();

        uint256 amount = msg.value;
        uint256 share = _sharesForDepositAmount(amount);
        if (amount > type(uint128).max || amount == 0 || share == 0) revert InvalidAmount();

        shares += share;

        emit AddLiquidity(amount, share, getTotalPooledEther(), shares);

        // todo mint frax
        // send to EigenLayer strategies
    }

    function _sharesForDepositAmount(uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        return (_depositAmount * shares) / totalPooledEther;
    }

    function getRate() external view returns (uint256) {
        // todo create a cadence mechanism to create epochs and then within epochs liquidate rewards

        uint256 totalShares = shares;
        if (totalShares == 0) {
            return 1 ether;
        }
        return (1 ether * getTotalPooledEther()) / totalShares;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return address(this).balance; // TODO upgrade later given system for staking, etc
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
