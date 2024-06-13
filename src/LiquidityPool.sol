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
import "./interfaces/IfrxETHMinter.sol";
import "@frxETH/IsfrxETH.sol";
import "forge-std/console.sol"; // todo remove
/**
 * @title LiquidityPool
 * @dev Contracts holds ETH and determines the global rate
 */

/*
TODO
 - Study using ERC4626 instead to abstract logic
*/
contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Amount of total shares issued
    uint256 public shares;

    /// @notice Address of the frax minter
    address public fraxMinter;

    function initialize(address _depositsManager, address _owner) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0)) revert InvalidAddress();

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        transferOwnership(_owner);
    }

    /** FUNDS MANAGEMENT */

    /// @notice Received ETH and mints shares to determine rate
    function addLiquidity() external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        uint256 amount = msg.value;
        uint256 share = _sharesForDepositAmount(amount);
        if (amount > type(uint128).max || amount == 0 || share == 0) revert InvalidAmount();

        shares += share;

        emit AddLiquidity(amount, share, getTotalPooledEther(), shares);

        // mint sfrxETH
        _stakeETH();

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
        IsfrxETH sfrxETH = IsfrxETH(IfrxETHMinter(fraxMinter).sfrxETHToken());
        uint256 sfrxETH_balance = sfrxETH.balanceOf(address(this));
        return address(this).balance + sfrxETH_balance;
    }

    /** YIELD STRATEGIES */

    function _stakeETH() internal {
        if (fraxMinter == address(0)) revert StrategyNotSet();
        IfrxETHMinter(fraxMinter).submitAndDeposit{value: address(this).balance}(address(this));
    }

    function setFraxMinter(address _fraxMinter) external onlyOwner {
        if (_fraxMinter == address(0)) revert InvalidAddress();
        fraxMinter = _fraxMinter;
    }

    /** OTHER */

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
