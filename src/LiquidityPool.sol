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
import { ICurvePool } from "./interfaces/ICurvePool.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";

import { IsfrxETH } from "@frxETH/IsfrxETH.sol";
import { IStrategyManager, IStrategy, IDelegationManager } from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import { ISignatureUtils } from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

/// @title LiquidityPool
/// @dev Manages ETH liquidity, staking, and yield strategies
contract LiquidityPool is Initializable, OwnableAccessControl, UUPSUpgradeable, ILiquidityPool {
    using FixedPointMathLib for uint256;

    error ImplementationIsNotContract(address newImplementation);

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    /// @notice Contract authorized to manage deposits
    address private depositsManager;

    /// @notice sfrxETH token contract
    IsfrxETH public sfrxETH;

    /// @notice Total shares issued
    uint256 public totalShares;

    /// @notice Address receiving protocol fees
    address public protocolTreasury;

    /// @notice Protocol fee percentage (in PRECISION)
    uint256 public protocolFee;

    /// @notice Accumulated protocol fees not yet paid out
    uint256 public protocolAccruedFees;

    /// @notice Last recorded total pooled ETH
    uint256 private lastTotalPooledEther;

    /// @notice frxETH minter contract
    IfrxETHMinter public fraxMinter;

    /// @notice EigenLayer strategy manager contract
    IStrategyManager public eigenLayerStrategyManager;

    /// @notice EigenLayer strategy contract
    IStrategy public eigenLayerStrategy;

    /// @notice EigenLayer delegation manager contract
    IDelegationManager public eigenLayerDelegationManager;

    /// @notice Curve pool for frxETH to ETH conversion
    ICurvePool public frxETHCurvePool;

    /// @dev Initializes the contract
    /// @param _depositsManager Address authorized to manage deposits
    /// @param _owner Contract owner address
    /// @param _service Service address for access control
    function initialize(address _depositsManager, address payable _owner, address _service) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0) || _service == address(0)) revert InvalidAddress();

        __OwnableAccessControl_init();
        __UUPSUpgradeable_init();

        depositsManager = _depositsManager;
        setService(_service);
        transferOwnership(_owner);

        protocolFee = 1e17; // 10%
        protocolTreasury = _owner;
    }

    /// @notice Adds liquidity to the pool increasing shares and receiving assets
    /// @dev Can be used to increase assets without increasing the rate given DOFT is not minted
    function addLiquidity() public payable {
        uint256 amount = msg.value;

        if (amount <= 0) revert InvalidAmount();
        (uint256 shares, uint256 totalPooledAssets) = _convertToShares(amount);
        if (shares <= 0) revert InvalidAmount();

        totalShares += shares;

        emit AddLiquidity(amount, shares, totalPooledAssets, shares);
    }

    /// @notice Processes liquidity, paying out fees and restaking assets
    function processLiquidity() external payable {
        if (msg.value > 0) addLiquidity();

        uint256 balance = address(this).balance;

        // pay-out fees
        if (protocolAccruedFees > 0 && balance > 0) {
            uint256 toPay = protocolAccruedFees > balance ? balance : protocolAccruedFees;
            protocolAccruedFees -= toPay;
            balance -= toPay;
            // slither-disable-next-line arbitrary-send-eth,low-level-calls
            (bool success, ) = protocolTreasury.call{ value: toPay }("");
            if (!success) revert TransferFailed(protocolTreasury);
        }

        // mint sfrxETH & restake
        if (balance > 0) {
            _mintSfrxETH();

            // send to EigenLayer strategies
            _eigenLayerRestake();
        }
    }

    /// @notice Calculates total assets in the pool
    /// @return Total assets in ETH
    function totalAssets() public view returns (uint256) {
        uint256 sfrxETHBalance = 0;

        if (address(sfrxETH) != address(0)) {
            sfrxETHBalance = sfrxETH.balanceOf(address(this));
        }

        // EigenLayer restaked sfrxETH
        if (address(eigenLayerStrategy) != address(0)) {
            sfrxETHBalance += eigenLayerStrategy.userUnderlyingView(address(this));
        }

        uint256 frxETHBalance = sfrxETH.convertToAssets(sfrxETHBalance);

        // Convert frxETH to ETH using Curve pool price
        uint256 ethBalance;
        if (address(frxETHCurvePool) != address(0)) {
            uint256 frxETHPrice = frxETHCurvePool.get_p();
            ethBalance = (frxETHBalance * frxETHPrice) / PRECISION;
        } else {
            ethBalance = frxETHBalance; // Fallback to 1:1 if Curve pool is not set
        }

        return address(this).balance + ethBalance - protocolAccruedFees;
    }

    /// @dev Converts deposit amount to shares
    /// @param _deposit Amount of ETH to deposit
    /// @return shares Number of shares minted
    /// @return totalPooledEtherWithDeposit Total pooled ETH after deposit
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

    /// @notice Get current exchange rate of shares to ETH
    /// @return Rate in ETH per share (in PRECISION)
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

    /// @dev Mints sfrxETH with available ETH balance
    function _mintSfrxETH() internal {
        uint256 balance = address(this).balance;
        if (address(fraxMinter) == address(0) || balance <= 0) return;
        // slither-disable-next-line arbitrary-send-eth
        if (fraxMinter.submitAndDeposit{ value: balance }(address(this)) <= 0) revert MintFailed();
    }

    /// @notice Sets the frxETH minter address
    /// @param _fraxMinter Address of the frxETH minter contract
    function setFraxMinter(address _fraxMinter) external onlyOwner {
        if (_fraxMinter == address(0)) revert InvalidAddress();

        fraxMinter = IfrxETHMinter(_fraxMinter);
        sfrxETH = IsfrxETH(fraxMinter.sfrxETHToken());
    }

    /// @dev Restakes sfrxETH in EigenLayer
    function _eigenLayerRestake() internal {
        if (address(eigenLayerStrategyManager) == address(0) || address(fraxMinter) == address(0)) return;

        uint256 sfrxETHBalance = sfrxETH.balanceOf(address(this));
        if (!sfrxETH.approve(address(eigenLayerStrategyManager), sfrxETHBalance)) revert ApprovalFailed();

        uint256 shares = eigenLayerStrategyManager.depositIntoStrategy(eigenLayerStrategy, IERC20(address(sfrxETH)), sfrxETHBalance);
        if (shares <= 0) revert StrategyFailed();
    }

    /// @notice Delegates to an operator in EigenLayer
    /// @param _operator Address of the operator to delegate to
    function delegateEigenLayer(address _operator) external onlyService {
        if (address(eigenLayerDelegationManager) == address(0)) revert InvalidEigenLayerStrategy();
        if (_operator == address(0)) revert InvalidAddress();
        eigenLayerDelegationManager.delegateTo(_operator, ISignatureUtils.SignatureWithExpiry("", 0), "");
    }

    /// @notice Fallback function to receive ETH
    receive() external payable {}

    /// @notice Sets the address of the Curve pool used for frxETH/ETH price
    /// @param _curvePool The address of the Curve pool contract
    function setCurvePool(address _curvePool) external onlyOwner {
        if (_curvePool == address(0)) revert InvalidAddress();
        frxETHCurvePool = ICurvePool(_curvePool);
    }

    /// @notice Sets EigenLayer contracts
    /// @param _strategyManager Address of EigenLayer strategy manager
    /// @param _strategy Address of EigenLayer strategy
    /// @param _delegationManager Address of EigenLayer delegation manager
    function setEigenLayer(address _strategyManager, address _strategy, address _delegationManager) external onlyOwner {
        if (_strategyManager == address(0) || _strategy == address(0) || _delegationManager == address(0)) revert InvalidAddress();
        if (address(sfrxETH) == address(0)) revert LSTMintingNotSet();
        if (address(sfrxETH) != address(IStrategy(_strategy).underlyingToken())) revert InvalidEigenLayerStrategy();

        eigenLayerStrategyManager = IStrategyManager(_strategyManager);
        eigenLayerStrategy = IStrategy(_strategy);
        eigenLayerDelegationManager = IDelegationManager(_delegationManager);
    }

    /// @notice Sets the protocol fee
    /// @param _fee New fee value (in PRECISION)
    function setProtocolFee(uint256 _fee) external onlyOwner {
        if (_fee > PRECISION) revert InvalidFee();
        protocolFee = _fee;
        emit ProtocolFeeUpdated(_fee, msg.sender);
    }

    /// @notice Sets the protocol treasury address
    /// @param _treasury New treasury address
    function setProtocolTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        protocolTreasury = _treasury;
    }

    /// @dev Calculates fee amount
    /// @param _amountIn Input amount
    /// @param _fee Fee percentage (in PRECISION)
    /// @return feeAmount Calculated fee amount
    function _getFee(uint256 _amountIn, uint256 _fee) internal pure returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    /// @dev Authorizes an upgrade to a new implementation
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
