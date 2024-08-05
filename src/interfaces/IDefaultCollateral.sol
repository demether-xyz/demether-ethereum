// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICollateral } from "./ICollateral.sol";

interface IDefaultCollateral is ICollateral {
    error NotLimitIncreaser();
    error InsufficientDeposit();
    error ExceedsLimit();
    error InsufficientWithdraw();
    error InsufficientIssueDebt();

    /**
     * @notice Get a maximum possible collateral total supply.
     * @return maximum collateral total supply
     */
    function limit() external view returns (uint256);

    /**
     * @notice Deposit a given amount of the underlying asset, and mint the collateral to a particular recipient.
     * @param recipient address of the collateral's recipient
     * @param amount amount of the underlying asset
     * @return amount of the collateral minted
     */
    function deposit(address recipient, uint256 amount) external returns (uint256);

    /**
     * @notice Withdraw a given amount of the underlying asset, and transfer it to a particular recipient.
     * @param recipient address of the underlying asset's recipient
     * @param amount amount of the underlying asset
     */
    function withdraw(address recipient, uint256 amount) external;
}
