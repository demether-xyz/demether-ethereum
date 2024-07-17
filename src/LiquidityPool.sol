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
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { IsfrxETH } from "@frxETH/IsfrxETH.sol";
import { IfrxETHMinter } from "./interfaces/IfrxETHMinter.sol";
import { ILiquidityPool } from "./interfaces/ILiquidityPool.sol";
import { ISignatureUtils } from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import { IStrategyManager, IStrategy, IDelegationManager } from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";

/**
 * @title LiquidityPool
 * @dev Contracts holds ETH and determines the global rate
 */

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    // Custom error
    error ImplementationIsNotContract(address newImplementation);

    using FixedPointMathLib for uint256;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Instance of the sfrxETH token
    IsfrxETH public sfrxETH;

    /// @notice Amount of total shares issued
    uint256 public totalShares;

    /// @notice Protocol fee destination
    address public protocolTreasury;

    /// @notice Fee charged for protocol on rewards
    uint256 public protocolFee;

    /// @notice Total fees accrued not yet paid out
    uint256 public protocolAccruedFees;

    /// @notice Tracks the last total pooled ether
    uint256 private lastTotalPooledEther;

    /// @notice Address of the frax minter
    address public fraxMinter;

    /// @notice Address of the EigenLayer strategy manager
    address public eigenLayerStrategyManager;

    /// @notice Address of the EigenLayer strategy
    address public eigenLayerStrategy;

    /// @notice Address of the EigenLayer delegation manager
    address public eigenLayerDelegationManager;

    function initialize(address _depositsManager, address _owner) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0)) revert InvalidAddress();

        __Ownable_init();
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

        // pay-out fees
        uint256 balance = address(this).balance;
        if (protocolAccruedFees > 0 && balance > 0) {
            uint256 toPay = protocolAccruedFees > balance ? balance : protocolAccruedFees;
            protocolAccruedFees -= toPay;
            (bool success, ) = protocolTreasury.call{ value: toPay }("");
            if (!success) revert TransferFailed(protocolTreasury);
        }

        // mint sfrxETH
        if (address(this).balance > 0) {
            _mintSfrxETH();

            // send to EigenLayer strategies
            _eigenLayerRestake();
        }
    }

    function totalAssets() public view virtual returns (uint256) {
        uint256 sfrxEthBalance = 0;
        // uint256 eigenLayerBalance = 0; commenting this as this is unsed atm

        if (address(sfrxETH) != address(0)) {
            sfrxEthBalance = sfrxETH.balanceOf(address(this));
        }

        // EigenLayer restaked sfrxETH
        if (eigenLayerStrategyManager != address(0)) {
            IStrategy strategy = IStrategy(eigenLayerStrategy);
            sfrxEthBalance += strategy.userUnderlyingView(address(this));
        }

        // TODO this gives frxETH, but must be converted to ETH
        uint256 frxEthBalance = sfrxETH.convertToAssets(sfrxEthBalance);

        return address(this).balance + frxEthBalance - protocolAccruedFees;
    }

    function _convertToShares(uint256 _deposit) internal returns (uint256 shares, uint256 totalPooledEtherWithDeposit) {
        uint256 supply = totalShares;
        totalPooledEtherWithDeposit = totalAssets();
        uint256 totalPooledEther = totalPooledEtherWithDeposit - _deposit;

        // Adjust for rewards
        if (lastTotalPooledEther != 0 && totalPooledEther > lastTotalPooledEther) {
            uint256 newRewards = totalPooledEther - lastTotalPooledEther;
            uint256 rewardsFee = _getFee(newRewards, protocolFee);
            emit RewardsProtocol(rewardsFee);

            totalPooledEther -= rewardsFee;
            totalPooledEtherWithDeposit -= rewardsFee;
            protocolAccruedFees += rewardsFee;
        }
        lastTotalPooledEther = totalPooledEtherWithDeposit;
        shares = supply == 0 ? _deposit : _deposit.mulDivDown(supply, totalPooledEther);
    }

    function getRate() external view returns (uint256) {
        uint256 supply = totalShares;
        uint256 totalPooledEther = totalAssets();

        // Adjust for rewards
        if (lastTotalPooledEther != 0 && totalPooledEther > lastTotalPooledEther) {
            uint256 newRewards = totalPooledEther - lastTotalPooledEther;
            uint256 rewardsFee = _getFee(newRewards, protocolFee);
            totalPooledEther -= rewardsFee;
        }

        uint256 amount = 1 ether;
        return supply == 0 ? amount : amount.mulDivDown(totalPooledEther, supply);
    }

    /** YIELD STRATEGIES */

    // TODO discuss how to handle pause, limits, other. Potentially try/catch
    function _mintSfrxETH() internal {
        if (fraxMinter == address(0)) return;

        IfrxETHMinter(fraxMinter).submitAndDeposit{ value: address(this).balance }(address(this));
    }

    function setFraxMinter(address _fraxMinter) external onlyOwner {
        if (_fraxMinter == address(0)) revert InvalidAddress();

        fraxMinter = _fraxMinter;
        sfrxETH = IsfrxETH(IfrxETHMinter(fraxMinter).sfrxETHToken());
    }

    /** RESTAKING **/

    // TODO discuss how to handle pause, limits, other. Potentially try/catch
    function _eigenLayerRestake() internal {
        if (eigenLayerStrategyManager == address(0) || fraxMinter == address(0)) return;

        uint256 sfrxEthBalance = sfrxETH.balanceOf(address(this));
        if (!sfrxETH.approve(eigenLayerStrategyManager, sfrxEthBalance)) revert ApprovalFailed();

        uint256 shares = IStrategyManager(eigenLayerStrategyManager).depositIntoStrategy(
            IStrategy(eigenLayerStrategy),
            IERC20(address(sfrxETH)),
            sfrxEthBalance
        );
        if (shares == 0) revert StrategyFailed(eigenLayerStrategyManager);
    }

    function delegateEigenLayer(address _operator) external onlyOwner {
        if (eigenLayerDelegationManager == address(0)) revert InvalidEigenLayerStrategy();
        if (_operator == address(0)) revert InvalidAddress();
        IDelegationManager(eigenLayerDelegationManager).delegateTo(
            _operator,
            ISignatureUtils.SignatureWithExpiry("", 0),
            ""
        );
    }

    function setEigenLayer(address _strategyManager, address _strategy, address _delegationManager) external onlyOwner {
        if (_strategyManager == address(0) || _strategy == address(0) || _delegationManager == address(0))
            revert InvalidAddress();
        if (address(sfrxETH) == address(0)) revert LSTMintingNotSet();

        if (address(sfrxETH) != address(IStrategy(_strategy).underlyingToken())) revert InvalidEigenLayerStrategy();

        eigenLayerStrategyManager = _strategyManager;
        eigenLayerStrategy = _strategy;
        eigenLayerDelegationManager = _delegationManager;
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

    function _getFee(uint256 _amountIn, uint256 _fee) internal pure returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
