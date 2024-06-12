pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IDOFT.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IMessenger.sol";
import "./interfaces/IDepositsManager.sol";

/**
 * @title L1 Deposits Manager
 * @dev Base contract for Layer 1
 * Main entry interface allows users to deposit tokens on Layer 1
 */

/*
TODO
    -Change erros format
*/
contract DepositsManagerL1 is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IDepositsManager
{
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

    function initialize(address _wETH, address _owner, bool _nativeSupport) external initializer onlyProxy {
        require(_wETH != address(0), "Invalid wETH");

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
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

    function getConversionAmount(uint256 _amountIn) public returns (uint256 amountOut) {
        uint256 depositFee = 0; // TODO create system for fees setting, depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
        uint256 rate = getRate();
        uint256 feeAmount = (_amountIn * depositFee + PRECISION_SUB_ONE) / PRECISION;
        uint256 amountInAfterFee = _amountIn - feeAmount;
        amountOut = (amountInAfterFee * PRECISION) / rate;
        return amountOut;
    }

    function getRate() public view returns (uint256) {
        return pool.getRate();
    }

    /// @notice Adds into Liquidity Pool to start producing yield
    function addLiquidity() external whenNotPaused nonReentrant {
        wETH.withdraw(wETH.balanceOf(address(this)));
        pool.addLiquidity{value: address(this).balance}();
    }

    /** SYNC with L2 **/

    function syncRate(uint32[] calldata _chainId, uint256[] calldata _chainFee) external payable whenNotPaused nonReentrant {
        if (_chainId.length != _chainFee.length) revert InvalidParametersLength();
        bytes memory data = abi.encode(MESSAGE_SYNC_RATE, block.number, getRate());
        uint256 totalFees = 0;
        for (uint256 i = 0; i < _chainId.length; i++) {
            messenger.syncMessage{value: _chainFee[i]}(_chainId[i], data, msg.sender);
            totalFees += _chainFee[i];
        }
        if (msg.value < totalFees) revert InsufficientFee();
    }

    function onMessageReceived(uint32 _chainId, bytes calldata _message) external nonReentrant {
        //        if (msg.sender != address(messenger) || _chainId != ETHEREUM_CHAIN_ID) revert Unauthorized();
        revert("not implemented");
    }

    /** OTHER **/

    receive() external payable {}

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IDOFT(_token);
    }

    function setLiquidityPool(address _pool) external onlyOwner {
        require(_pool != address(0), "Invalid pool");
        pool = ILiquidityPool(_pool);
    }

    function setMessenger(address _messenger) external onlyOwner {
        if (_messenger == address(0)) revert InvalidAddress();
        messenger = IMessenger(_messenger);
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
