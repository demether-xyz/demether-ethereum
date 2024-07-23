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
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IDOFT.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IMessenger.sol";
import "./interfaces/IDepositsManager.sol";
import "./OwnableAccessControl.sol";
import "forge-std/console.sol"; // todo remove
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
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint32 internal constant ETHEREUM_CHAIN_ID = 1;
    uint256 private constant MESSAGE_SYNC_RATE = 1;

    /// @notice Instances of mintable token
    IDOFT public token;

    /// @notice Instance of messenger handler
    IMessenger public messenger;

    /// @notice Wrapped ETH instance
    IWETH9 private wETH;

    /// @notice Chain native token is ETH
    bool private nativeSupport;

    /// @notice Deposit fee in 1e18 precision to cover gas and slippage
    uint256 public depositFee;

    /// @notice Exchange rate from L1
    uint256 private rate;

    /// @notice Rate block
    uint256 public rateSyncBlock;

    // Custom errors
    error DepositFailed(address sender, uint256 amount);
    error NativeTokenNotSupported();
    error ZeroAmount();
    error TokenMintFailed(address tokenReceiver, uint256 amount);
    error ImplementationIsNotContract(address newImplementation);
    error InvalidFee();

    function initialize(address _wETH, address _owner, address _service, bool _nativeSupport) external initializer onlyProxy {
        require(_wETH != address(0), "Invalid wETH");

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        nativeSupport = _nativeSupport;

        setService(_service);
        transferOwnership(_owner);
    }

    function deposit(uint256 _amountIn, address _referral) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!wETH.transferFrom(msg.sender, address(this), _amountIn)) revert DepositFailed(msg.sender, _amountIn);
        amountOut = _deposit(_amountIn, _referral);
    }

    function depositETH(address _referral) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!nativeSupport) revert NativeTokenNotSupported();
        wETH.deposit{value: address(this).balance}();
        amountOut = _deposit(msg.value, _referral);
    }

    function _deposit(uint256 _amountIn, address _referral) internal returns (uint256 amountOut) {
        if (_amountIn == 0) revert ZeroAmount();
        amountOut = getConversionAmount(_amountIn);
        emit Deposit(msg.sender, _amountIn, amountOut, _referral);
        if (!token.mint(msg.sender, amountOut)) revert TokenMintFailed(msg.sender, amountOut);
    }

    function getConversionAmount(uint256 _amountIn) public view returns (uint256 amountOut) {
        if (rateSyncBlock == 0) revert RateInvalid(rate);
        uint256 feeAmount = (_amountIn * depositFee + PRECISION_SUB_ONE) / PRECISION;
        uint256 amountInAfterFee = _amountIn - feeAmount;
        amountOut = (amountInAfterFee * PRECISION) / rate;
        return amountOut;
    }

    function getRate() public view returns (uint256) {
        return rate;
    }

    /** SYNC with L1 **/

    /// @notice Sync tokens specifying amount to transfer to limit slippage
    function syncTokens(uint256 _amount) external payable whenNotPaused nonReentrant {
        if (_amount == 0 || _amount > wETH.balanceOf(address(this))) revert InvalidSyncAmount();
        messenger.syncTokens{value: msg.value}(ETHEREUM_CHAIN_ID, _amount, msg.sender);
    }

    function onMessageReceived(uint32 _chainId, bytes calldata _message) external nonReentrant {
        if (msg.sender != address(messenger) || _chainId != ETHEREUM_CHAIN_ID) revert Unauthorized();
        uint256 code = abi.decode(_message, (uint256));
        if (code == MESSAGE_SYNC_RATE) {
            (, uint256 _block, uint256 _rate) = abi.decode(_message, (uint256, uint256, uint256));
            if (_block > rateSyncBlock) {
                rate = _rate;
                rateSyncBlock = _block;
            }
        } else {
            revert InvalidMessageCode();
        }
    }

    /** OTHER **/

    // TODO change to service modifier
    function setDepositFee(uint256 _fee) external onlyOwner {
        if (_fee >= PRECISION) revert InvalidFee();
        depositFee = _fee;
        emit DepositFeeSet(_fee);
    }

    function setToken(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        token = IDOFT(_token);
    }

    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
        wETH.approve(_messenger, type(uint256).max);
    }

    function pause() external onlyService whenNotPaused {
        _pause();
    }

    function unpause() external onlyService whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
