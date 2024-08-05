// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IDefaultCollateral } from "../../src/interfaces/IDefaultCollateral.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDefaultCollateral is IDefaultCollateral, ERC20 {
    IERC20 public immutable underlyingAsset;
    uint256 private _limit;

    constructor(IERC20 _underlyingAsset, string memory name, string memory symbol, uint256 initialLimit) ERC20(name, symbol) {
        underlyingAsset = _underlyingAsset;
        _limit = initialLimit;
    }

    function limit() external view returns (uint256) {
        return _limit;
    }

    function deposit(address recipient, uint256 amount) external returns (uint256) {
        if (totalSupply() + amount > _limit) revert ExceedsLimit();
        if (!underlyingAsset.transferFrom(msg.sender, address(this), amount)) revert InsufficientDeposit();

        _mint(recipient, amount);
        return amount;
    }

    function withdraw(address recipient, uint256 amount) external {
        if (balanceOf(msg.sender) < amount) revert InsufficientWithdraw();
        _burn(msg.sender, amount);
        if (!underlyingAsset.transfer(recipient, amount)) revert InsufficientWithdraw();
    }

    function asset() external view returns (address) {
        return address(underlyingAsset);
    }

    // Stub implementations for ICollateral functions
    function issueDebt(address recipient, uint256 amount) external {
        if (totalSupply() + amount > _limit) revert ExceedsLimit();
        _mint(recipient, amount);
    }

    function repayDebt(address, uint256 amount) external {
        if (balanceOf(msg.sender) < amount) revert InsufficientIssueDebt();
        _burn(msg.sender, amount);
    }

    function liquidate(address debtor, address recipient, uint256 amount) external {
        if (balanceOf(debtor) < amount) revert InsufficientIssueDebt();
        _transfer(debtor, recipient, amount);
    }

    // Added missing functions
    function recipientDebt(address) external pure returns (uint256) {
        return 0;
    }

    function recipientRepaidDebt(address) external pure returns (uint256) {
        return 0;
    }

    function repaidDebt(address, address) external pure returns (uint256) {
        return 0;
    }

    function totalDebt() external view returns (uint256) {
        return totalSupply();
    }

    function totalRepaidDebt() external pure returns (uint256) {
        return 0;
    }

    // These were missing in the previous version as well
    function debt(address, address) external pure returns (uint256) {
        return 0;
    }

    function issuerDebt(address) external pure returns (uint256) {
        return 0;
    }

    function issuerRepaidDebt(address) external pure returns (uint256) {
        return 0;
    }
}
