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
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import { IDOFT } from "./interfaces/IDOFT.sol";
import { ILiquidityPool } from "./interfaces/ILiquidityPool.sol";
import { IMessenger } from "./interfaces/IMessenger.sol";
import { IDepositsManager } from "./interfaces/IDepositsManager.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";

/// @title L1 Deposits Manager for Demether Finance
/// @dev Manages deposits on Layer 1, interfacing with liquidity pools and facilitating cross-chain transfers
/// @notice Handles user deposits, token minting, and cross-chain communication
contract DepositsManagerL1 is
    Initializable,
    OwnableAccessControl,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IDepositsManager
{
    using OptionsBuilder for bytes;

    uint256 internal constant PRECISION = 1e18;
    uint256 private constant MESSAGE_SYNC_RATE = 1;

    /// @dev Token instance capable of minting
    IDOFT public token;
    /// @dev Liquidity pool for managing funds
    ILiquidityPool public pool;
    /// @dev Messenger for handling cross-chain messages
    IMessenger public messenger;

    /// @notice Initializes the contract with essential addresses and flags
    /// @param _owner Owner address with admin privileges
    /// @param _service Service address for contract control
    function initialize(address _owner, address _service) external initializer onlyProxy {
        if (_owner == address(0) || _service == address(0)) revert InvalidAddress();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __OwnableAccessControl_init(_owner, _service);
    }

    /// @notice Handles ETH deposits
    /// @param _chainId Target chain ID for cross-chain transfer (0 for local minting)
    /// @param _fee Fee associated with the transfer
    /// @param _referral Referral address for potential rewards
    /// @return amountOut Amount of tokens minted or transferred
    function depositETH(
        uint32 _chainId,
        uint256 _fee,
        address _referral
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (msg.value == 0 || msg.value <= _fee) revert InvalidAmount();
        if (address(pool) == address(0)) revert InstanceNotSet();

        uint256 _amountIn = msg.value - _fee;

        // Mint locally or send to a supported chain
        if (_chainId == 0) {
            if (_fee > 0) revert InvalidFee();
            amountOut = getConversionAmount(_amountIn);
            if (amountOut == 0) revert InvalidAmount();
            emit Deposit(msg.sender, _amountIn, amountOut, _referral);
            if (!token.mint(msg.sender, amountOut)) revert TokenMintFailed(msg.sender, amountOut);
        } else {
            // get settings for chain ensuring it's set
            if (address(messenger) == address(0)) revert InstanceNotSet();
            IMessenger.Settings memory settings = messenger.getMessageSettings(_chainId);
            if (settings.bridgeChainId == 0) revert InvalidChainId();

            amountOut = getConversionAmount(_amountIn);
            if (amountOut == 0) revert InvalidAmount();
            emit Deposit(msg.sender, _amountIn, amountOut, _referral);

            // mint to this contract
            if (!token.mint(address(this), amountOut)) revert TokenMintFailed(msg.sender, amountOut);

            // Calculate native fee as LayerZero vanilla OFT send using ~60k wei of native gas
            bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000 wei, 0);
            SendParam memory sendParam = SendParam(
                settings.bridgeChainId,
                addressToBytes32(msg.sender),
                amountOut,
                amountOut,
                options,
                "",
                ""
            );
            MessagingFee memory fee = MessagingFee(_fee, 0);

            // send through LayerZero
            // slither-disable-next-line unused-return
            (MessagingReceipt memory receipt, ) = token.send{ value: _fee }(sendParam, fee, payable(msg.sender));
            if (receipt.guid == 0) revert SendFailed(msg.sender, amountOut);
        }

        // add liquidity
        // slither-disable-next-line arbitrary-send-eth
        pool.addLiquidity{ value: address(this).balance }();
    }

    /// @notice Add liquidity without minting tokens
    /// @dev Only to be used for balancing, not by end user deposits
    function addLiquidity() external payable whenNotPaused nonReentrant {
        if (address(pool) == address(0)) revert InstanceNotSet();
        // slither-disable-next-line arbitrary-send-eth
        pool.addLiquidity{ value: msg.value }();
    }

    /// @notice Processes liquidity, paying out fees and restaking assets
    function processLiquidity() external whenNotPaused nonReentrant {
        if (address(pool) == address(0)) revert InstanceNotSet();
        // slither-disable-next-line arbitrary-send-eth
        pool.processLiquidity{ value: address(this).balance }();
    }

    /// @notice Calculates the amount of tokens to be minted based on the deposited amount and current rate
    /// @param _amountIn The amount of tokens deposited
    /// @return amountOut The amount of mintable tokens
    function getConversionAmount(uint256 _amountIn) public view returns (uint256 amountOut) {
        uint256 rate = getRate();
        amountOut = (_amountIn * PRECISION) / rate;
        return amountOut;
    }

    /// @notice Retrieves the current conversion rate from the liquidity pool
    /// @return Current rate of conversion between deposited tokens and minted tokens
    function getRate() public view returns (uint256) {
        if (address(pool) == address(0)) revert InstanceNotSet();
        return pool.getRate();
    }

    /// @notice Synchronizes rates across L1 and L2 chains
    /// @param _chainId Array of chain IDs to sync with
    /// @param _chainFee Array of fees for each chain message
    function syncRate(uint32[] calldata _chainId, uint256[] calldata _chainFee) external payable whenNotPaused nonReentrant {
        if (_chainId.length != _chainFee.length) revert InvalidParametersLength();
        if (address(messenger) == address(0)) revert InstanceNotSet();

        bytes memory data = abi.encode(MESSAGE_SYNC_RATE, block.number, block.timestamp, getRate());
        uint256 totalFees = 0;
        for (uint256 i = 0; i < _chainId.length; i++) {
            // slither-disable-next-line arbitrary-send-eth,calls-loop
            messenger.syncMessage{ value: _chainFee[i] }(_chainId[i], data, msg.sender);
            totalFees += _chainFee[i];
        }
        if (msg.value < totalFees) revert InsufficientFee();
    }

    /// @dev Handles incoming messages from other chains for withdrawals
    function onMessageReceived(uint32, bytes calldata) external nonReentrant {
        // Placeholder for actual implementation
        revert NotImplemented();
    }

    /// @notice Fallback function to receive ETH
    receive() external payable {}

    /// @notice Assigns a new token contract address
    /// @param _token New token contract address
    function setToken(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        token = IDOFT(_token);
    }

    /// @notice Assigns a new liquidity pool contract address
    /// @param _pool New liquidity pool contract address
    function setLiquidityPool(address _pool) external onlyOwner {
        if (_pool == address(0)) revert InvalidAddress();
        pool = ILiquidityPool(_pool);
    }

    /// @notice Assigns a new messenger contract address for cross-chain communications
    /// @param _messenger New messenger contract address
    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
    }

    /// @notice Pauses all deposit and liquidity operations
    function pause() external onlyService whenNotPaused {
        _pause();
    }

    /// @notice Resumes all deposit and liquidity operations
    function unpause() external onlyService whenPaused {
        _unpause();
    }

    /// @dev Converts an address to a bytes32 value
    /// @param _addr Address to convert
    /// @return bytes32 representation of the address
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /// @dev Authorizes upgrades of the contract
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
