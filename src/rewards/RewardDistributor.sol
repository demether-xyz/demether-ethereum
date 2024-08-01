// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract RewardDistributor is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    bytes32 public totalRewardMerkleRoot;
    uint256 public claimStartTime;
    uint256 public claimEndTime;

    IERC20 public rewardToken;
    mapping(address => uint256) private claimedAmount;

    /* ============ Events ============ */

    event ClaimEvent(address account, uint256 amount);

    /* ============ Events ============ */

    error ClaimPeriodCompleted();
    error InvalidProof();

    /* ============ Constructor ============ */

    constructor(IERC20 _reward, bytes32 _totalRewardMerkleRoot) Ownable(){
        rewardToken = _reward;
        totalRewardMerkleRoot = _totalRewardMerkleRoot;
        claimStartTime = block.timestamp;
        claimEndTime = block.timestamp + 90 days;
    }

    /* ============ External Getters ============ */

    function getClaimed(address account) public view returns (uint256) {
        return claimedAmount[account];
    }

    function getClaimable(address account, uint256 totalAmount, bytes32[] calldata merkleProof) public view returns (uint256) {        
        if(block.timestamp >= claimEndTime){
            return 0;
        }

        if (!verifyProof(account, totalAmount, merkleProof)) {
            return 0;
        }

        return _getClaimable(account, totalAmount);
    }

    /* ============ External Functions ============ */

    function verifyProof(address account, uint256 amount,  bytes32[] calldata merkleProof) public view returns (bool) {
         bytes32 node = keccak256(abi.encodePacked(account, amount));
         return MerkleProof.verify(
                merkleProof,
                totalRewardMerkleRoot,
                node
        );
    }

    function claim(uint256 totalAmount, bytes32[] calldata merkleProof) external whenNotPaused nonReentrant {
        if(block.timestamp >= claimEndTime){
            revert ClaimPeriodCompleted();
        }

        //Verify the merkle proof.
        if(!verifyProof(msg.sender, totalAmount, merkleProof)){
            revert InvalidProof();
        }

        uint256 claimable = _getClaimable(msg.sender, totalAmount);

        // Mark it claimed and send the token.
        rewardToken.safeTransfer(msg.sender, claimable);
        uint256 userClaimedAmount = claimedAmount[msg.sender];
        claimedAmount[msg.sender] = userClaimedAmount + claimable;
        emit ClaimEvent(msg.sender, claimable);
    }

    /* ============ Internal Functions ============ */

    function _getClaimable(address account, uint256 totalAmount) internal view returns (uint256) {
        uint256 claimed = getClaimed(account);
        if (claimed >= totalAmount) {
            return 0;
        }
        return totalAmount - claimed;
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
