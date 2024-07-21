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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { ILiquidityPool } from "./interfaces/ILiquidityPool.sol";
import { IfrxETHMinter } from "./interfaces/IfrxETHMinter.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";

import { IsfrxETH } from "@frxETH/IsfrxETH.sol";
import { IStrategyManager, IStrategy, IDelegationManager } from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import { ISignatureUtils } from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

/**
 * @title LiquidityPool
 * @dev Contracts holds ETH and determines the global rate
 */

contract LiquidityPool is Initializable, OwnableAccessControl, UUPSUpgradeable, ILiquidityPool {
    using FixedPointMathLib for uint256;

    error ImplementationIsNotContract(address newImplementation);

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Instance of the sfrxETH token
    IsfrxETH public sfrxETH;

    /// @notice Amount of total shares issued
    uint256 public totalShares;

    /// @notice Protocol fee destination
    address payable public protocolTreasury;

    /// @notice Fee charged for protocol on rewards
    uint256 public protocolFee;

    /// @notice Total fees accrued not yet paid out
    uint256 public protocolAccruedFees;

    /// @notice Tracks the last total pooled ether
    uint256 private lastTotalPooledEther;

    /// @notice Instance of the frax minter
    IfrxETHMinter public fraxMinter;

    /// @notice Address of the EigenLayer strategy manager
    IStrategyManager public eigenLayerStrategyManager;

    /// @notice Instance of the EigenLayer strategy
    IStrategy public eigenLayerStrategy;

    /// @notice Instance of the EigenLayer delegation manager
    IDelegationManager public eigenLayerDelegationManager;

    function initialize(address _depositsManager, address payable _owner, address _service) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0) || _service == address(0)) revert InvalidAddress();

        __Ownable_init();
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        setService(_service);
        transferOwnership(_owner);

        // initial fee setting
        protocolFee = 1e17; // 10%;
        protocolTreasury = _owner;
    }

    /** FUNDS MANAGEMENT */

    /// @notice Received ETH and mints shares to determine rate
    /// @param _process Whether to process the liquidity
    function addLiquidity(bool _process) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        // convert to shares
        uint256 amount = msg.value;
        if (amount > 0) {
            (uint256 shares, uint256 totalPooledAssets) = _convertToShares(amount);
            if (shares <= 0) revert InvalidAmount();

            totalShares += shares;

            emit AddLiquidity(amount, shares, totalPooledAssets, shares);
        }

        // process liquidity
        if (_process) {
            uint256 balance = address(this).balance;

            // pay-out fees
            if (protocolAccruedFees > 0 && balance > 0) {
                uint256 toPay = protocolAccruedFees > balance ? balance : protocolAccruedFees;
                protocolAccruedFees -= toPay;
                balance -= toPay;
                protocolTreasury.transfer(toPay);
            }

            // mint sfrxETH & restake
            if (balance > 0) {
                _mintSfrxETH();

                // send to EigenLayer strategies
                _eigenLayerRestake();
            }
        }
    }

    function totalAssets() public view returns (uint256) {
        uint256 sfrxETHBalance = 0;

        if (address(sfrxETH) != address(0)) {
            sfrxETHBalance = sfrxETH.balanceOf(address(this));
        }

        // EigenLayer restaked sfrxETH
        if (address(eigenLayerStrategy) != address(0)) {
            sfrxETHBalance += eigenLayerStrategy.userUnderlyingView(address(this));
        }

        // TODO this gives frxETH, but must be converted to ETH
        uint256 frxETHBalance = sfrxETH.convertToAssets(sfrxETHBalance);

        return address(this).balance + frxETHBalance - protocolAccruedFees;
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
        shares = supply <= 0 ? _deposit : _deposit.mulDivDown(supply, totalPooledEther);
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
        return supply <= 0 ? amount : amount.mulDivDown(totalPooledEther, supply);
    }

    /** YIELD STRATEGIES */

    // TODO discuss how to handle pause, limits, other. Potentially try/catch
    function _mintSfrxETH() internal {
        uint256 balance = address(this).balance;
        if (address(fraxMinter) == address(0) || balance <= 0) return;
        // slither-disable-next-line arbitrary-send-eth
        if (fraxMinter.submitAndDeposit{ value: balance }(address(this)) <= 0) revert MintFailed();
    }

    function setFraxMinter(address _fraxMinter) external onlyOwner {
        if (_fraxMinter == address(0)) revert InvalidAddress();

        fraxMinter = IfrxETHMinter(_fraxMinter);
        sfrxETH = IsfrxETH(fraxMinter.sfrxETHToken());
    }

    /** RESTAKING **/

    // TODO discuss how to handle pause, limits, other. Potentially try/catch
    function _eigenLayerRestake() internal {
        if (address(eigenLayerStrategyManager) == address(0) || address(fraxMinter) == address(0)) return;

        uint256 sfrxETHBalance = sfrxETH.balanceOf(address(this));
        if (!sfrxETH.approve(address(eigenLayerStrategyManager), sfrxETHBalance)) revert ApprovalFailed();

        uint256 shares = eigenLayerStrategyManager.depositIntoStrategy(eigenLayerStrategy, IERC20(address(sfrxETH)), sfrxETHBalance);
        if (shares <= 0) revert StrategyFailed();
    }

    function delegateEigenLayer(address _operator) external onlyService {
        if (address(eigenLayerDelegationManager) == address(0)) revert InvalidEigenLayerStrategy();
        if (_operator == address(0)) revert InvalidAddress();
        eigenLayerDelegationManager.delegateTo(_operator, ISignatureUtils.SignatureWithExpiry("", 0), "");
    }

    function setEigenLayer(address _strategyManager, address _strategy, address _delegationManager) external onlyOwner {
        if (_strategyManager == address(0) || _strategy == address(0) || _delegationManager == address(0)) revert InvalidAddress();
        if (address(sfrxETH) == address(0)) revert LSTMintingNotSet();

        if (address(sfrxETH) != address(IStrategy(_strategy).underlyingToken())) revert InvalidEigenLayerStrategy();

        eigenLayerStrategyManager = IStrategyManager(_strategyManager);
        eigenLayerStrategy = IStrategy(_strategy);
        eigenLayerDelegationManager = IDelegationManager(_delegationManager);
    }

    /** OTHER */

    function setProtocolFee(uint256 _fee) external onlyOwner {
        if (_fee > PRECISION) revert InvalidFee();
        protocolFee = _fee;
        emit ProtocolFeeUpdated(_fee, msg.sender);
    }

    function setProtocolTreasury(address payable _treasury) external onlyOwner {
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
