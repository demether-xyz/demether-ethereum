// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { IfrxETHMinter } from "../../src/interfaces/IfrxETHMinter.sol";

contract MockSfrxETH is ERC4626, Ownable {
    constructor(IERC20 asset) ERC4626(asset) ERC20("Staked Frax Ether", "sfrxETH") Ownable() {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Override to implement custom logic if needed
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return super.convertToAssets(shares);
    }

    // Override to implement custom logic if needed
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return super.convertToShares(assets);
    }
}

contract MockFrxETH is ERC20, Ownable {
    constructor() ERC20("Frax Ether", "frxETH") Ownable() {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract MockFrxETHMinter is IfrxETHMinter, Ownable {
    MockSfrxETH public sfrxETH;
    MockFrxETH public frxETHToken;

    constructor() Ownable() {
        frxETHToken = new MockFrxETH();
        sfrxETH = new MockSfrxETH(frxETHToken);
        frxETHToken.transferOwnership(address(this));
        sfrxETH.transferOwnership(address(this));
    }

    function submitAndDeposit(address recipient) external payable override returns (uint256 shares) {
        require(msg.value > 0, "Must send ETH");

        // Mint frxETH tokens to this contract
        uint256 frxETHAmount = msg.value; // 1:1 ratio for simplicity
        frxETHToken.mint(address(this), frxETHAmount);

        // Approve sfrxETH to spend frxETH
        frxETHToken.approve(address(sfrxETH), frxETHAmount);

        // Deposit frxETH and mint sfrxETH to recipient
        shares = sfrxETH.deposit(frxETHAmount, recipient);

        return shares;
    }

    /// @notice Mint frxETH to the recipient using sender's funds
    function submitAndGive(address recipient) external payable override {
        require(msg.value > 0, "Must send ETH");

        // Mint frxETH tokens directly to the recipient
        uint256 frxETHAmount = msg.value; // 1:1 ratio for simplicity
        frxETHToken.mint(recipient, frxETHAmount);
    }

    function sfrxETHToken() external view override returns (address) {
        return address(sfrxETH);
    }

    // Additional function to withdraw ETH (for testing purposes)
    function withdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        recipient.transfer(amount);
    }
}
