// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IDepositsManager
/// @dev Interface for Layer 1 and Layer 2 Deposits Managers
interface IDepositsManager {
    /// @dev Thrown when synchronization amount is invalid
    error InvalidSyncAmount();
    /// @dev Thrown when input parameters length is incorrect
    error InvalidParametersLength();
    /// @dev Thrown when provided fee is insufficient
    error InsufficientFee();
    /// @dev Thrown when fee is invalid
    error InvalidFee();
    /// @dev Thrown on unauthorized action
    error Unauthorized();
    /// @dev Thrown on invalid message code in cross-chain communication
    error InvalidMessageCode();
    /// @dev Thrown when provided rate is invalid
    error RateInvalid(uint256);
    /// @dev Thrown on invalid chain ID for cross-chain operations
    error InvalidChainId();
    /// @dev Thrown when deposit or transfer amount is invalid
    error InvalidAmount();
    /// @dev Thrown when a deposit fails
    error DepositFailed(address sender, uint256 amount);
    /// @dev Thrown when native token is not supported
    error NativeTokenNotSupported();
    /// @dev Thrown when token minting fails
    error TokenMintFailed(address tokenReceiver, uint256 amount);
    /// @dev Thrown on upgrade attempt to non-contract address
    error ImplementationIsNotContract(address newImplementation);
    /// @dev Thrown when called function is not implemented
    error NotImplemented();
    /// @dev Thrown when required contract instance is not set
    error InstanceNotSet();
    /// @dev Thrown when token send operation fails
    error SendFailed(address sender, uint256 amount);
    /// @dev Thrown when token approval fails
    error ApprovalFailed();
    /// @dev Thrown when fee is non zero while minting locally
    error NonZeroFeeForLocalMinting(uint256 fee);

    /// @dev Emitted on successful deposit
    /// @param user Address of depositor
    /// @param amountIn Amount deposited
    /// @param amountOut Amount credited to user
    /// @param referral Referral address
    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut, address referral);

    /// @dev Emitted when deposit fee is updated
    /// @param fee New deposit fee
    event DepositFeeSet(uint256 fee);

    /// @dev Emitted when deposit rate is updated
    /// @param newRate New conversion rate
    /// @param blockNumber Block number of update
    event RateUpdated(uint256 newRate, uint256 blockNumber);

    /// @dev Handles cross-chain message reception
    /// @param chainId Originating chain ID
    /// @param message Encoded message data
    function onMessageReceived(uint32 chainId, bytes calldata message) external;

    /// @dev Gets current deposit conversion rate
    /// @return Current rate
    function getRate() external view returns (uint256);
}
