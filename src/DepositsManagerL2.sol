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
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import { IDOFT } from "./interfaces/IDOFT.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { IMessenger } from "./interfaces/IMessenger.sol";
import { IDepositsManager } from "./interfaces/IDepositsManager.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";
/**
 * @title L2 Deposits Manager
 * @dev Base contract for Layer 2
 * Main entry interface allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 */
contract DepositsManagerL2 is
    Initializable,
    OwnableAccessControl,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IDepositsManager
{
    using OptionsBuilder for bytes;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant FEE_DEPOSIT_MAX = 2e16; // 2%
    uint256 internal constant FEE_DEPOSIT_MIN = 1e14; // 0.01%
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint32 internal constant ETHEREUM_CHAIN_ID = 1;
    uint256 private constant MESSAGE_SYNC_RATE = 1;

    /// @notice Mintable token instance
    IDOFT public token;

    /// @notice Messenger handler instance
    IMessenger public messenger;

    /// @notice Wrapped ETH instance
    IWETH9 private wETH;

    /// @notice Indicates if native token (ETH) deposits are supported
    bool private nativeSupport;

    /// @notice Deposit fee in 1e18 precision for gas and slippage coverage
    uint256 public depositFee;

    /// @notice Exchange rate from L1
    uint256 private rate;

    /// @notice Block number of the last rate sync
    uint256 public rateSyncBlock;

    /// @notice Block timestamp of the last rate sync
    uint256 public rateSyncTimestamp;

    /// @notice Maximum allowed time (in seconds) for rate staleness
    uint256 public maxRateStaleness;

    /// @notice Initializes the contract with essential parameters
    /// @param _wETH Address of the Wrapped ETH contract
    /// @param _owner Address of the contract owner
    /// @param _service Address of the service account
    /// @param _nativeSupport Whether native token deposits are supported
    function initialize(address _wETH, address _owner, address _service, bool _nativeSupport) external initializer onlyProxy {
        if (_wETH == address(0) || _owner == address(0) || _service == address(0)) revert InvalidAddress();

        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __OwnableAccessControl_init(_owner, _service);

        wETH = IWETH9(_wETH);
        nativeSupport = _nativeSupport;
        maxRateStaleness = 3 days;
    }

    /// @notice Deposits tokens and optionally bridges to another chain
    /// @param _amountIn Amount of tokens to deposit
    /// @param _chainId Target chain ID (0 for local minting)
    /// @param _referral Referral address
    /// @return amountOut Amount of tokens minted
    function deposit(
        uint256 _amountIn,
        uint32 _chainId,
        address _referral
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!wETH.transferFrom(msg.sender, address(this), _amountIn)) revert DepositFailed(msg.sender, _amountIn);
        amountOut = _deposit(_amountIn, _chainId, msg.value, _referral);
    }

    /// @notice Deposits native ETH and optionally bridges to another chain
    /// @param _chainId Target chain ID (0 for local minting)
    /// @param _fee LayerZero fee for cross-chain transfers
    /// @param _referral Referral address
    /// @return amountOut Amount of tokens minted
    function depositETH(
        uint32 _chainId,
        uint256 _fee,
        address _referral
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!nativeSupport) revert NativeTokenNotSupported();
        uint256 amountIn = msg.value - _fee;
        wETH.deposit{ value: address(this).balance - _fee }();
        amountOut = _deposit(amountIn, _chainId, _fee, _referral);
    }

    /// @notice Internal function to process deposits
    /// @param _amountIn Amount of tokens to deposit
    /// @param _chainId Target chain ID
    /// @param _fee LayerZero fee
    /// @param _referral Referral address
    /// @return amountOut Amount of tokens minted
    function _deposit(uint256 _amountIn, uint32 _chainId, uint256 _fee, address _referral) internal returns (uint256 amountOut) {
        if (_amountIn == 0 || msg.value < _fee) revert InvalidAmount();
        if (address(token) == address(0)) revert InvalidAddress();
        if (address(messenger) == address(0)) revert InvalidAddress();

        // Mints Locally or mints and sends to a supported chain
        if (_chainId == 0) {
            if (_fee > 0) revert InvalidFee();
            amountOut = getConversionAmount(_amountIn);
            if (amountOut == 0) revert InvalidAmount();
            emit Deposit(msg.sender, _amountIn, amountOut, _referral);
            if (!token.mint(msg.sender, amountOut)) revert TokenMintFailed(msg.sender, amountOut);
        } else {
            // get settings for chain ensuring it's set
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
                amountOut, // amount is temporary to calculate quote
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
    }

    /// @notice Calculates the output amount based on input and current rate
    /// @param _amountIn Input amount
    /// @return amountOut Converted output amount
    function getConversionAmount(uint256 _amountIn) public view returns (uint256 amountOut) {
        if (rateSyncBlock == 0) revert RateInvalid(rate);

        // Check if the rate is stale
        // slither-disable-next-line timestamp
        if (block.timestamp - rateSyncTimestamp > maxRateStaleness) {
            revert RateStale();
        }

        uint256 feeAmount = (_amountIn * depositFee + PRECISION_SUB_ONE) / PRECISION;
        uint256 amountInAfterFee = _amountIn - feeAmount;
        amountOut = (amountInAfterFee * PRECISION) / rate;
        return amountOut;
    }

    /// @notice Returns the current exchange rate
    /// @return Current rate
    function getRate() public view returns (uint256) {
        return rate;
    }

    /// @notice Syncs tokens with L1, specifying amount to transfer
    /// @param _amount Amount of tokens to sync
    function syncTokens(uint256 _amount) external payable whenNotPaused nonReentrant {
        if (_amount == 0 || _amount > wETH.balanceOf(address(this))) revert InvalidSyncAmount();
        if (address(messenger) == address(0)) revert InvalidAddress();
        messenger.syncTokens{ value: msg.value }(ETHEREUM_CHAIN_ID, _amount, msg.sender);
    }

    /// @notice Handles incoming messages from L1
    /// @param _chainId Source chain ID
    /// @param _message Received message
    function onMessageReceived(uint32 _chainId, bytes calldata _message) external nonReentrant {
        if (msg.sender != address(messenger) || _chainId != ETHEREUM_CHAIN_ID) revert Unauthorized();
        uint256 code = abi.decode(_message, (uint256));
        if (code == MESSAGE_SYNC_RATE) {
            (, uint256 _block, uint256 _timestamp, uint256 _rate) = abi.decode(_message, (uint256, uint256, uint256, uint256));
            if (_block > rateSyncBlock) {
                rate = _rate;
                rateSyncBlock = _block;
                rateSyncTimestamp = _timestamp;
                emit RateUpdated(_rate, _block, _timestamp);
            }
        } else {
            revert InvalidMessageCode();
        }
    }

    /// @notice Sets the deposit fee
    /// @param _fee New fee value
    function setDepositFee(uint256 _fee) external onlyService {
        if (_fee < FEE_DEPOSIT_MIN || _fee > FEE_DEPOSIT_MAX) revert InvalidFee();
        depositFee = _fee;
        emit DepositFeeSet(_fee);
    }

    /// @notice Sets the maximum allowed time for rate staleness
    /// @param _maxStaleness Maximum staleness time in seconds
    function setMaxRateStaleness(uint256 _maxStaleness) external onlyOwner {
        maxRateStaleness = _maxStaleness;
        emit MaxRateStalenessUpdated(_maxStaleness);
    }

    /// @notice Sets the token contract address
    /// @param _token New token address
    function setToken(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        token = IDOFT(_token);
    }

    /// @notice Sets the messenger contract address
    /// @param _messenger New messenger address
    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
        if (!wETH.approve(_messenger, type(uint256).max)) revert ApprovalFailed();
    }

    /// @notice Pauses the contract
    function pause() external onlyService whenNotPaused {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyService whenPaused {
        _unpause();
    }

    /// @notice Converts an address to bytes32
    /// @param _addr Address to convert
    /// @return Bytes32 representation of the address
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
