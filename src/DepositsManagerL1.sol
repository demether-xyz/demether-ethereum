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
import { ILiquidityPool } from "./interfaces/ILiquidityPool.sol";
import { IMessenger } from "./interfaces/IMessenger.sol";
import { IDepositsManager } from "./interfaces/IDepositsManager.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";

/**
 * @title L1 Deposits Manager
 * @dev Base contract for Layer 1
 * Main entry interface allows users to deposit tokens on Layer 1
 */

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
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint256 private constant MESSAGE_SYNC_RATE = 1;

    /// @notice Instances of mintable token
    IDOFT public token;

    /// @notice Instance of liquidity pool
    ILiquidityPool public pool;

    /// @notice Instance of messenger handler
    IMessenger public messenger;

    /// @notice Wrapped ETH instance
    IWETH9 private wETH;

    /// @notice Chain native token is ETH
    bool private nativeSupport;

    function initialize(address _wETH, address _owner, address _service, bool _nativeSupport) external initializer onlyProxy {
        if (_wETH == address(0) || _owner == address(0) || _service == address(0)) revert InvalidAddress();

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        nativeSupport = _nativeSupport;

        setService(_service);
        transferOwnership(_owner);
    }

    function deposit(
        uint256 _amountIn,
        uint32 _chainId,
        uint256 _fee,
        address _referral
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!wETH.transferFrom(msg.sender, address(this), _amountIn)) revert DepositFailed(msg.sender, _amountIn);
        amountOut = _deposit(_amountIn, _chainId, _fee, _referral);
    }

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

    function _deposit(uint256 _amountIn, uint32 _chainId, uint256 _fee, address _referral) internal returns (uint256 amountOut) {
        if (_amountIn == 0 || msg.value < _fee) revert InvalidAmount();

        // Mints Locally or mints and sends to a supported chain
        if (_chainId == 0) {
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

    function getConversionAmount(uint256 _amountIn) public view returns (uint256 amountOut) {
        uint256 rate = getRate();
        amountOut = (_amountIn * PRECISION) / rate;
        return amountOut;
    }

    function getRate() public view returns (uint256) {
        if (address(pool) == address(0)) revert InstanceNotSet();
        return pool.getRate();
    }

    /// @notice Adds into Liquidity Pool to start producing yield
    function addLiquidity() external whenNotPaused nonReentrant {
        if (address(pool) == address(0)) revert InstanceNotSet();
        wETH.withdraw(wETH.balanceOf(address(this)));
        // slither-disable-next-line arbitrary-send-eth
        pool.addLiquidity{ value: address(this).balance }();
    }

    /** SYNC with L2 **/

    function syncRate(uint32[] calldata _chainId, uint256[] calldata _chainFee) external payable whenNotPaused nonReentrant {
        if (_chainId.length != _chainFee.length) revert InvalidParametersLength();
        if (address(messenger) == address(0)) revert InstanceNotSet();

        bytes memory data = abi.encode(MESSAGE_SYNC_RATE, block.number, getRate());
        uint256 totalFees = 0;
        for (uint256 i = 0; i < _chainId.length; i++) {
            // slither-disable-next-line arbitrary-send-eth
            messenger.syncMessage{ value: _chainFee[i] }(_chainId[i], data, msg.sender);
            totalFees += _chainFee[i];
        }
        if (msg.value < totalFees) revert InsufficientFee();
    }

    /// @dev Function to be used when withdrawals are enabled
    function onMessageReceived(uint32, bytes calldata) external nonReentrant {
        //if (msg.sender != address(messenger) || _chainId != ETHEREUM_CHAIN_ID) revert Unauthorized();
        revert NotImplemented();
    }

    /** OTHER **/

    receive() external payable {}

    function setToken(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        token = IDOFT(_token);
    }

    function setLiquidityPool(address _pool) external onlyOwner {
        if (_pool == address(0)) revert InvalidAddress();
        pool = ILiquidityPool(_pool);
    }

    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
    }

    function pause() external onlyService whenNotPaused {
        _pause();
    }

    function unpause() external onlyService whenPaused {
        _unpause();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
