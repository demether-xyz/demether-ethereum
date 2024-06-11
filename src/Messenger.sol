// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IMessenger.sol";
import "./interfaces/IWETH9.sol";
/**
 * @title Messenger
 * @dev Contracts sends messages and tokens across chains
 */

interface IStargateRouterETH {
    function swapETH(
        uint16 _dstChainId, // destination Stargate chainId
        address payable _refundAddress, // refund additional messageFee to this address
        bytes calldata _toAddress, // the receiver of the destination ETH
        uint256 _amountLD, // the amount, in Local Decimals, to be swapped
        uint256 _minAmountLD // the minimum amount accepted out on destination
    ) external payable;
}

contract Messenger is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IMessenger
{
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_v2 = 3;

    /// @notice wETH instance
    IWETH9 public wETH;

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Mapping for each destination chainId settings
    mapping(uint32 => Settings) public settings;

    function initialize(
        address _wETH,
        address _depositsManager,
        address _owner
    ) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0))
            revert InvalidAddress();

        __Ownable_init(); // TODO determine upgrade policy and other auth processes
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        wETH.approve(_depositsManager, type(uint256).max);

        depositsManager = _depositsManager;

        transferOwnership(_owner);
    }

    /** MAIN METHODS **/

    function syncTokens(
        uint32 _destination,
        uint256 _amount,
        address _refund
    ) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        Settings memory _settings = settings[_destination];
        if (msg.value < _settings.minFee) revert FeeInsufficient();

        emit SyncTokens(
            _destination,
            _settings.bridgeId,
            _amount,
            _settings.maxSlippage
        );

        // route call
        if (_settings.bridgeId == STARGATE) {
            wETH.transferFrom(msg.sender, address(this), _amount);
            _sync_StartGateV1(_settings, _amount, _refund);
        } else {
            revert BridgeNotSupported();
        }
    }

    function setSyncSettings(
        uint32 _destination,
        Settings calldata _settings
    ) external onlyOwner {
        settings[_destination] = _settings;
    }

    /** STARGATE **/

    function _sync_StartGateV1(
        Settings memory _settings,
        uint256 _amount,
        address _refund
    ) internal {
        uint256 maxSlippage = _getFee(_amount, _settings.maxSlippage);
        wETH.withdraw(_amount);
        IStargateRouterETH(_settings.router).swapETH{
            value: _amount + msg.value
        }(
            uint16(_settings.bridgeChainId), // send to Fuji (use LayerZero chainId)
            payable(_refund), // refund adddress. extra gas (if any) is returned to this address
            abi.encodePacked(_settings.toAddress), // the address to send the tokens to on the destination
            _amount, // quantity to swap in LD, (local decimals)
            _amount - maxSlippage // the min qty you would accept in LD (local decimals)
        );
    }

    function _getFee(
        uint256 _amountIn,
        uint256 _fee
    ) internal returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    receive() external payable {}

    function _authorizeUpgrade(
        address _newImplementation
    ) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert InvalidContract();
    }
}
