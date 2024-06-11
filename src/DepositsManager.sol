// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IDOFT.sol";
import "./interfaces/IWETH9.sol";

/**
 * @title Abstract Deposits Manager
 * @dev Base contract with basic flows
 */
contract DepositsManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;

    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut);

    /// @notice Instances of mintable token
    IDOFT public token;

    /// @notice Wrapped ETH instance
    IWETH9 private wETH;

    /// @notice Chain native token is ETH
    bool private nativeSupport;

    function initialize(
        address _wETH,
        address _owner
    ) external initializer onlyProxy {
        require(_wETH != address(0), "Invalid wETH");

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);

        transferOwnership(_owner);
    }

    function deposit(
        uint256 _amountIn
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        require(
            wETH.transferFrom(address(msg.sender), address(this), _amountIn),
            "Deposit Failed"
        );
        amountOut = _deposit(_amountIn);
    }

    function depositETH()
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
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

    // todo check method given the dust audit
    function getConversionAmount(
        uint256 _amountIn
    ) public returns (uint256 amountOut) {
        // TODO move to module for exchange rate of itself that gets rates from L1
        uint256 depositFee = 1e15; // TODO create system for fees setting, depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
        uint256 rate = 1e18; // TODO system to get the rates
        uint256 feeAmount = (_amountIn * depositFee + PRECISION_SUB_ONE) /
            PRECISION;
        uint256 amountInAfterFee = _amountIn - feeAmount;
        amountOut = (amountInAfterFee * PRECISION) / rate;
        return amountOut;
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IDOFT(_token);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(
        address _newImplementation
    ) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "NOT_CONTRACT");
    }
}
