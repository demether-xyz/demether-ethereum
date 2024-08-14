// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IRewardDistributor } from "../interfaces/IRewardDistributor.sol";

contract RewardDistributor is Ownable, Pausable, ReentrancyGuard, IRewardDistributor {
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    bytes32 public totalRewardMerkleRoot;
    uint256 public claimStartTime;
    uint256 public claimEndTime;

    IERC20 public rewardToken;
    mapping(address user => uint256 amount) private claimedAmount;

    /* ============ Constructor ============ */

    constructor(IERC20 _reward, bytes32 _totalRewardMerkleRoot) Ownable() {
        rewardToken = _reward;
        totalRewardMerkleRoot = _totalRewardMerkleRoot;
        claimStartTime = block.timestamp;
        claimEndTime = block.timestamp + 90 days;
    }

    /* ============ External Getters ============ */

    function getClaimed(address account) public view returns (uint256) {
        if (account == address(0)) revert InvalidAddress();
        return claimedAmount[account];
    }

    function getClaimable(address account, uint256 amount, bytes32[] calldata merkleProof) public view returns (uint256) {
        if (account == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (merkleProof.length == 0) revert InvalidMerkleProof();
        if (block.timestamp >= claimEndTime) {
            return 0;
        }

        if (!verifyProof(account, amount, merkleProof)) {
            return 0;
        }

        return _getClaimable(account, amount);
    }

    /* ============ External Functions ============ */

    function verifyProof(address account, uint256 amount, bytes32[] calldata merkleProof) public view returns (bool) {
        if (account == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (merkleProof.length == 0) revert InvalidMerkleProof();
        bytes32 node = keccak256(abi.encodePacked(account, amount));
        return MerkleProof.verify(merkleProof, totalRewardMerkleRoot, node);
    }

    function claim(uint256 amount, bytes32[] calldata merkleProof) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (merkleProof.length == 0) revert InvalidMerkleProof();
        if (block.timestamp >= claimEndTime) {
            revert ClaimPeriodCompleted();
        }

        //Verify the merkle proof.
        if (!verifyProof(msg.sender, amount, merkleProof)) {
            revert InvalidProof();
        }

        uint256 claimable = _getClaimable(msg.sender, amount);

        // Mark it claimed and send the token.
        rewardToken.safeTransfer(msg.sender, claimable);
        uint256 userClaimedAmount = claimedAmount[msg.sender];
        claimedAmount[msg.sender] = userClaimedAmount + claimable;
        emit ClaimEvent(msg.sender, claimable);
    }

    /* ============ Internal Functions ============ */

    function _getClaimable(address account, uint256 amount) internal view returns (uint256) {
        if (account == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 claimed = getClaimed(account);
        if (claimed >= amount) {
            return 0;
        }
        return amount - claimed;
    }

    /* ============ Admin functions ============ */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner whenPaused {
        rewardToken.safeTransfer(owner(), rewardToken.balanceOf((address(this))));
    }
}
