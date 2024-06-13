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
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "@frxETH/IsfrxETH.sol";

import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IfrxETHMinter.sol";
import "forge-std/console.sol"; // todo remove
/**
 * @title LiquidityPool
 * @dev Contracts holds ETH and determines the global rate
 */

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    using FixedPointMathLib for uint256;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Amount of total shares issued
    uint256 public totalShares;

    /// @notice Address of the frax minter
    address public fraxMinter;

    /// @notice Protocol fee destination
    address public protocolTreasury;

    /// @notice Tracks the last total pooled ether
    uint256 private lastTotalPooledEther;

    /// @notice Fee charged for protocol on rewards
    uint256 public protocolFee;

    function initialize(address _depositsManager, address _owner) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0)) revert InvalidAddress();

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        transferOwnership(_owner);

        // initial fee setting
        protocolFee = 1e17; // 10%;
        protocolTreasury = _owner;
    }

    /** FUNDS MANAGEMENT */

    /// @notice Received ETH and mints shares to determine rate
    function addLiquidity() external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        uint256 amount = msg.value;
        (uint256 shares, uint256 totalPooledAssets) = _convertToShares(amount);
        if (amount == 0 || shares == 0) revert InvalidAmount();

        totalShares += shares;

        emit AddLiquidity(amount, shares, totalPooledAssets, shares);

        // mint sfrxETH
        _stakeETH();

        // send to EigenLayer strategies
    }

    function totalAssets() public view virtual returns (uint256) {
        IsfrxETH sfrxETH = IsfrxETH(IfrxETHMinter(fraxMinter).sfrxETHToken());
        uint256 sfrxETH_balance = sfrxETH.balanceOf(address(this));
        return address(this).balance + sfrxETH_balance;
    }

    function _convertToShares(uint256 _deposit) internal returns (uint256 shares, uint256 totalPooledEtherWithDeposit) {
        uint256 supply = totalShares;
        totalPooledEtherWithDeposit = totalAssets();
        uint256 totalPooledEther = totalPooledEtherWithDeposit - _deposit;

        // Adjust for rewards
        if (lastTotalPooledEther != 0) {
            uint256 newRewards = totalPooledEther - lastTotalPooledEther;
            uint256 rewardsFee = _getFee(newRewards, protocolFee);
            emit RewardsProtocol(rewardsFee);

            totalPooledEther -= rewardsFee;
            totalPooledEtherWithDeposit -= rewardsFee;

            (bool success, ) = protocolTreasury.call{value: rewardsFee}("");
            if (!success) revert TransferFailed(protocolTreasury);
        }
        lastTotalPooledEther = totalPooledEtherWithDeposit;
        shares = supply == 0 ? _deposit : _deposit.mulDivDown(supply, totalPooledEther);
    }

    function getRate() external view returns (uint256) {
        uint256 supply = totalShares;
        uint256 totalPooledEther = totalAssets();

        // Adjust for rewards
        if (lastTotalPooledEther != 0) {
            uint256 newRewards = totalPooledEther - lastTotalPooledEther;
            uint256 rewardsFee = _getFee(newRewards, protocolFee);
            totalPooledEther -= rewardsFee;
        }

        uint256 amount = 1 ether;
        return supply == 0 ? amount : amount.mulDivDown(totalPooledEther, supply);
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

    function setProtocolFee(uint256 _fee) external onlyOwner {
        if (_fee > 3e16) revert InvalidFee();
        protocolFee = _fee;
    }

    function setProtocolTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        protocolTreasury = _treasury;
    }

    function _getFee(uint256 _amountIn, uint256 _fee) internal view returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
