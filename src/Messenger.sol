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
import {
    ILayerZeroEndpointV2,
    MessagingFee,
    MessagingParams,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import { IMessenger } from "./interfaces/IMessenger.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { IDepositsManager } from "./interfaces/IDepositsManager.sol";
import { IStargateRouterETH } from "./interfaces/IStargateRouterETH.sol";
import { OwnableAccessControl } from "./OwnableAccessControl.sol";

/// @title Messenger
/// @dev Facilitates cross-chain message and token transfers
contract Messenger is Initializable, OwnableAccessControl, UUPSUpgradeable, IMessenger {
    using OptionsBuilder for bytes;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
    uint8 public constant LAYERZERO = 1;
    uint8 public constant STARGATE = 2;
    uint8 public constant STARGATE_V2 = 3;

    /// @notice WETH contract interface
    IWETH9 public wETH;

    /// @notice Address authorized to manage funds
    address private depositsManager;

    /// @notice Maps bridge IDs to their respective router addresses
    mapping(uint8 bridgeIds => address routerAddress) public routers;

    /// @notice Stores settings for message transfers to each destination chain
    mapping(uint32 destChainId => Settings settings) public settingsMessages;

    /// @notice Stores settings for each bridge and destination chain combination
    mapping(uint8 localBridgeId => mapping(uint32 destChainId => Settings settings)) public settingsMessagesBridges;

    /// @notice Stores settings for token transfers to each destination chain
    mapping(uint32 destChainId => Settings tokenSettings) public settingsTokens;

    /// @notice Initializes the contract with essential addresses and permissions
    /// @param _wETH Address of the WETH contract
    /// @param _depositsManager Address of the deposits manager
    /// @param _owner Address of the contract owner
    /// @param _service Address of the service account
    function initialize(address _wETH, address _depositsManager, address _owner, address _service) external initializer onlyProxy {
        if (_depositsManager == address(0) || _owner == address(0) || _service == address(0)) revert InvalidAddress();

        __Ownable_init();
        __UUPSUpgradeable_init();

        wETH = IWETH9(_wETH);
        depositsManager = _depositsManager;
        setService(_service);
        transferOwnership(_owner);

        if (!wETH.approve(_depositsManager, type(uint256).max)) revert ApprovalFailed();
    }

    /// @notice Transfers tokens across chains
    /// @param _destination Destination chain ID
    /// @param _amount Amount of tokens to transfer
    /// @param _refund Address to refund excess fees
    function syncTokens(uint32 _destination, uint256 _amount, address _refund) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        Settings memory settings = settingsTokens[_destination];
        if (msg.value < settings.minFee) revert InsufficientFee();

        emit SyncTokens(_destination, settings.bridgeId, _amount, settings.maxSlippage);

        address router = routers[settings.bridgeId];
        if (settings.bridgeId == 0 || settings.toAddress == address(0) || router == address(0)) {
            revert BridgeNotSupported();
        } else if (settings.bridgeId == STARGATE) {
            if (!wETH.transferFrom(msg.sender, address(this), _amount)) revert DepositFailed(msg.sender, _amount);
            _syncStartGateV1(settings, router, _amount, _refund);
        }
    }

    /// @notice Sends a message across chains
    /// @param _destination Destination chain ID
    /// @param _data Message data to be sent
    /// @param _refund Address to refund excess fees
    function syncMessage(uint32 _destination, bytes calldata _data, address _refund) external payable {
        if (msg.sender != depositsManager) revert Unauthorized();

        Settings memory settings = settingsMessages[_destination];
        if (msg.value < settings.minFee) revert InsufficientFee();

        address router = routers[settings.bridgeId];
        if (settings.bridgeId == 0 || settings.toAddress == address(0) || router == address(0)) {
            revert BridgeNotSupported();
        } else if (settings.bridgeId == LAYERZERO) {
            _syncLayerZero(settings, router, _data, _refund);
        }
    }

    /// @notice Updates settings for message transfers to a specific chain
    /// @param _destination Destination chain ID
    /// @param _settings New settings for the destination
    function setSettingsMessages(uint32 _destination, Settings calldata _settings) external onlyService {
        if (_destination == 0) revert InvalidChainId();
        settingsMessages[_destination] = _settings;
        settingsMessagesBridges[_settings.bridgeId][_settings.bridgeChainId] = _settings;
        emit SettingsMessages(_destination, _settings.bridgeId, _settings.toAddress);
    }

    /// @notice Updates settings for token transfers to a specific chain
    /// @param _destination Destination chain ID
    /// @param _settings New settings for the destination
    function setSettingsTokens(uint32 _destination, Settings calldata _settings) external onlyService {
        if (_destination == 0) revert InvalidChainId();
        settingsTokens[_destination] = _settings;
        emit SettingsTokens(_destination, _settings.bridgeId, _settings.toAddress);
    }

    /// @notice Sets router addresses for different bridge protocols
    /// @param _bridgeIds Array of bridge IDs
    /// @param _routers Array of corresponding router addresses
    /// @param _owner Address to set as the LayerZero delegate
    function setRouters(uint8[] calldata _bridgeIds, address[] calldata _routers, address _owner) external onlyOwner {
        if (_bridgeIds.length != _routers.length) revert InvalidParametersLength();

        for (uint256 i = 0; i < _bridgeIds.length; i++) {
            uint8 _bridgeId = _bridgeIds[i];
            address _router = _routers[i];

            if (_bridgeId == 0) revert BridgeNotSupported();
            if (_router == address(0)) revert InvalidAddress();
            // slither-disable-next-line reentrancy-benign
            routers[_bridgeId] = _router;

            if (_bridgeId == LAYERZERO) {
                if (_owner == address(0)) revert InvalidAddress();
                // slither-disable-next-line calls-loop
                ILayerZeroEndpointV2(_router).setDelegate(_owner);
            }
        }
    }

    /// @notice Retrieves message settings for a specific chain
    /// @param chainId The chain ID to query
    /// @return Settings struct for the specified chain
    function getMessageSettings(uint32 chainId) external view returns (Settings memory) {
        return settingsMessages[chainId];
    }

    /// @notice Internal function to handle LayerZero message transfers
    /// @param _settings Transfer settings
    /// @param _router LayerZero router address
    /// @param _data Message data to be sent
    /// @param _refund Address to refund excess fees
    function _syncLayerZero(Settings memory _settings, address _router, bytes calldata _data, address _refund) internal {
        bytes32 receiver = addressToBytes32(_settings.toAddress);
        uint128 _gas = abi.decode(_settings.options, (uint128));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gas, 0);
        MessagingReceipt memory receipt = ILayerZeroEndpointV2(_router).send{ value: msg.value }(
            MessagingParams(_settings.bridgeChainId, receiver, _data, options, false),
            _refund
        );
        if (receipt.guid == 0) revert SendMessageFailed();
    }

    /// @notice Handles incoming LayerZero messages
    /// @param _origin Origin information of the message
    /// @param _message The received message data
    function lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata) public payable virtual {
        Settings memory settings = settingsMessagesBridges[LAYERZERO][_origin.srcEid];
        address router = routers[settings.bridgeId];

        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (router != msg.sender) revert OnlyEndpoint(msg.sender);

        // Ensure that the sender matches the expected peer for the source endpoint.
        address sender = bytes32ToAddress(_origin.sender);
        if (settings.toAddress != sender) revert OnlyPeer(_origin.srcEid, sender);

        // Call the internal OApp implementation of lzReceive.
        IDepositsManager(depositsManager).onMessageReceived(settings.chainId, _message);
    }

    /// @notice Checks if a path initialization is allowed
    /// @param _origin Origin information of the message
    /// @return bool Indicating if initialization is allowed
    function allowInitializePath(Origin calldata _origin) public view virtual returns (bool) {
        Settings memory _settings = settingsMessages[_origin.srcEid];
        return addressToBytes32(_settings.toAddress) == _origin.sender;
    }

    /// @notice Quotes the fee for a LayerZero message
    /// @param _destination Destination chain ID
    /// @return uint256 The quoted fee in native currency
    function quoteLayerZero(uint32 _destination) public view returns (uint256) {
        Settings memory settings = settingsMessages[_destination];
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

    /// @notice Internal function to handle Stargate V1 token transfers
    /// @param _settings Transfer settings
    /// @param _router Stargate router address
    /// @param _amount Amount of tokens to transfer
    /// @param _refund Address to refund excess fees
    function _syncStartGateV1(Settings memory _settings, address _router, uint256 _amount, address _refund) internal {
        uint256 maxSlippage = _getFee(_amount, _settings.maxSlippage);
        wETH.withdraw(_amount);
        IStargateRouterETH(_router).swapETH{ value: _amount + msg.value }(
            uint16(_settings.bridgeChainId),
            payable(_refund),
            abi.encodePacked(_settings.toAddress),
            _amount,
            _amount - maxSlippage
        );
    }

    /// @notice Calculates fee amount based on input and fee percentage
    /// @param _amountIn Input amount
    /// @param _fee Fee percentage (in PRECISION units)
    /// @return feeAmount Calculated fee amount
    function _getFee(uint256 _amountIn, uint256 _fee) internal pure returns (uint256 feeAmount) {
        feeAmount = (_amountIn * _fee + PRECISION_SUB_ONE) / PRECISION;
    }

    /// @notice Converts bytes32 to address
    /// @param _bytes The bytes32 value to convert
    /// @return The resulting address
    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }

    /// @notice Converts address to bytes32
    /// @param _addr The address to convert
    /// @return The resulting bytes32 value
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}

    /// @notice Authorizes contract upgrades
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert InvalidContract();
    }
}
