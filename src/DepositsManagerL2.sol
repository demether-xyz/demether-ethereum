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
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IDOFT.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IMessenger.sol";
import "./interfaces/IDepositsManager.sol";
import "forge-std/console.sol"; // todo remove
/**
 * @title L2 Deposits Manager
 * @dev Base contract for Layer 2
 * Main entry interface allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 */
contract DepositsManagerL2 is
    Initializable,
    OwnableUpgradeable,
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

    /// @notice Exchange rate from L1
    uint256 private rate;

    /// @notice Rate block
    uint256 public rateSyncBlock;

    function initialize(address _wETH, address _owner, bool _nativeSupport) external initializer onlyProxy {
        require(_wETH != address(0), "Invalid wETH");

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        nativeSupport = _nativeSupport;

        transferOwnership(_owner);
    }

    function deposit(uint256 _amountIn) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        require(wETH.transferFrom(address(msg.sender), address(this), _amountIn), "Deposit Failed");
        amountOut = _deposit(_amountIn);
    }

    function depositETH() external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        require(nativeSupport, "Native token not supported");
        wETH.deposit{value: address(this).balance}();
        amountOut = _deposit(msg.value);
    }

    function _deposit(uint256 _amountIn) internal returns (uint256 amountOut) {
        require(_amountIn != 0, "Amount in zero");
        amountOut = getConversionAmount(_amountIn);
        emit Deposit(msg.sender, _amountIn, amountOut);
        require(token.mint(msg.sender, amountOut), "Token minting failed");
    }

    function getConversionAmount(uint256 _amountIn) public view returns (uint256 amountOut) {
        if (rateSyncBlock == 0) revert RateInvalid(rate);
        uint256 depositFee = 1e15; // TODO create system for fees setting, depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
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

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IDOFT(_token);
    }

    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
        wETH.approve(_messenger, type(uint256).max);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
