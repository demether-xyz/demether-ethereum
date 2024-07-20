// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositsManager {
    error InvalidAddress();
    error InvalidSyncAmount();
    error InvalidParametersLength();
    error InsufficientFee();
    error InvalidFee();
    error Unauthorized();
    error InvalidMessageCode();
    error RateInvalid(uint256);
    error InvalidChainId();
    error InvalidAmount();
    error DepositFailed(address sender, uint256 amount);
    error NativeTokenNotSupported();
    error TokenMintFailed(address tokenReceiver, uint256 amount);
    error ImplementationIsNotContract(address newImplementation);
    error NotImplemented();
    error InstanceNotSet();
    error SendFailed(address sender, uint256 amount);
    error ApprovalFailed();

    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut, address referral);
    event DepositFeeSet(uint256 fee);
    function onMessageReceived(uint32 chainId, bytes calldata message) external;
    function getRate() external view returns (uint256);
}
