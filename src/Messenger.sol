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
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILayerZeroEndpointV2, MessagingFee, MessagingParams, Origin} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import "./interfaces/IMessenger.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IDepositsManager.sol";
import "./OwnableAccessControl.sol";
import "forge-std/console.sol"; // todo remove
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

contract Messenger is Initializable, OwnableAccessControl, UUPSUpgradeable, IMessenger {
    using OptionsBuilder for bytes;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_v2 = 3;

    /// @notice wETH instance
    IWETH9 public wETH;

    /// @notice Contract able to manage the funds
    address private depositsManager;

    /// @notice Mapping of bridge ids to routers
    mapping(uint8 => address) public routers;

    /// @notice Mapping for each destination chainId messages settings
    mapping(uint32 => Settings) public settings_messages;

    /// @notice Mapping of local bridge id to settings
    mapping(uint8 => mapping(uint32 => Settings)) public settings_messages_bridges;

    /// @notice Mapping for each destination chainId tokens settings
    mapping(uint32 => Settings) public settings_tokens;

    function initialize(address _wETH, address _depositsManager, address _owner, address _service) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0)) revert InvalidAddress();

        __Ownable_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        wETH.approve(_depositsManager, type(uint256).max);

        depositsManager = _depositsManager;

        setService(_service);
        transferOwnership(_owner);
    }

    /** MAIN METHODS **/

    function syncTokens(uint32 _destination, uint256 _amount, address _refund) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        Settings memory settings = settings_tokens[_destination];
        if (msg.value < settings.minFee) revert InsufficientFee();

        emit SyncTokens(_destination, settings.bridgeId, _amount, settings.maxSlippage);

        address router = routers[settings.bridgeId];
        if (settings.bridgeId == 0 || settings.toAddress == address(0) || router == address(0)) {
            revert BridgeNotSupported();
        } else if (settings.bridgeId == STARGATE) {
            wETH.transferFrom(msg.sender, address(this), _amount);
            _sync_StartGateV1(settings, router, _amount, _refund);
        }
    }

    function syncMessage(uint32 _destination, bytes calldata _data, address _refund) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        Settings memory settings = settings_messages[_destination];
        if (msg.value < settings.minFee) revert InsufficientFee();

        address router = routers[settings.bridgeId];
        if (settings.bridgeId == 0 || settings.toAddress == address(0) || router == address(0)) {
            revert BridgeNotSupported();
        } else if (settings.bridgeId == LAYERZERO) {
            _sync_LayerZero(settings, router, _data, _refund);
        }
    }

    function setSettingsMessages(uint32 _destination, Settings calldata _settings) external onlyService {
        settings_messages[_destination] = _settings;
        settings_messages_bridges[_settings.bridgeId][_settings.bridgeChainId] = _settings;
        emit SettingsMessages(_destination, _settings.bridgeId, _settings.toAddress);
    }

    function setSettingsTokens(uint32 _destination, Settings calldata _settings) external onlyService {
        settings_tokens[_destination] = _settings;
        emit SettingsTokens(_destination, _settings.bridgeId, _settings.toAddress);
    }

    function setRouters(uint8[] calldata _bridgeIds, address[] calldata _routers, address _owner) external onlyOwner {
        if (_bridgeIds.length != _routers.length) revert InvalidParametersLength();

        for (uint i = 0; i < _bridgeIds.length; i++) {
            uint8 _bridgeId = _bridgeIds[i];
            address _router = _routers[i];

            if (_router == address(0)) revert InvalidAddress();
            routers[_bridgeId] = _router;

            if (_bridgeId == LAYERZERO) {
                if (_owner == address(0)) revert InvalidAddress();
                ILayerZeroEndpointV2(_router).setDelegate(_owner);
            }
        }
    }

    /** LAYER ZERO **/

    function _sync_LayerZero(Settings memory _settings, address _router, bytes calldata _data, address _refund) internal {
        bytes32 receiver = addressToBytes32(_settings.toAddress);
        uint128 _gas = abi.decode(_settings.options, (uint128));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gas, 0);
        ILayerZeroEndpointV2(_router).send{value: msg.value}(
            MessagingParams(_settings.bridgeChainId, receiver, _data, options, false),
            _refund
        );
    }

    function lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata) public payable virtual {
        Settings memory settings = settings_messages_bridges[LAYERZERO][_origin.srcEid];
        address router = routers[settings.bridgeId];

        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (router != msg.sender) revert OnlyEndpoint(msg.sender);

        // Ensure that the sender matches the expected peer for the source endpoint.
        address sender = bytes32ToAddress(_origin.sender);
        if (settings.toAddress != sender) revert OnlyPeer(_origin.srcEid, sender);

        // Call the internal OApp implementation of lzReceive.
        IDepositsManager(depositsManager).onMessageReceived(settings.chainId, _message);
    }

    function allowInitializePath(Origin calldata _origin) public view virtual returns (bool) {
        Settings memory _settings = settings_messages[_origin.srcEid];
        return addressToBytes32(_settings.toAddress) == _origin.sender;
    }

    function quoteLayerZero(uint32 _destination) public view returns (uint256) {
        Settings memory settings = settings_messages[_destination];
        bytes32 receiver = addressToBytes32(settings.toAddress);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);
        bytes memory data = abi.encode(1, 1 ether, 1 ether); // sample payload
        address router = routers[settings.bridgeId];
        MessagingFee memory fee = ILayerZeroEndpointV2(router).quote(
            MessagingParams(settings.bridgeChainId, receiver, data, options, false),
            address(this)
        );
        return fee.nativeFee;
    }

    /** STARGATE **/

    function _sync_StartGateV1(Settings memory _settings, address _router, uint256 _amount, address _refund) internal {
        uint256 maxSlippage = _getFee(_amount, _settings.maxSlippage);
        wETH.withdraw(_amount);
        IStargateRouterETH(_router).swapETH{value: _amount + msg.value}(
            uint16(_settings.bridgeChainId), // send to Fuji (use LayerZero chainId)
            payable(_refund), // refund adddress. extra gas (if any) is returned to this address
            abi.encodePacked(_settings.toAddress), // the address to send the tokens to on the destination
            _amount, // quantity to swap in LD, (local decimals)
            _amount - maxSlippage // the min qty you would accept in LD (local decimals)
        );
    }

    function _getFee(uint256 _amountIn, uint256 _fee) internal returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert InvalidContract();
    }
}
