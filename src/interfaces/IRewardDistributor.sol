// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IRewardDistributor
/// @dev Interface for DEM reward distribution contract
interface IRewardDistributor {
    /// @dev Thrown when an invalid (zero) address is provided.
    error InvalidAddress();

    /// @dev Thrown when the provided deposit or transfer amount is zero or otherwise invalid.
    error InvalidAmount();

    /// @dev Thrown when the provided Merkle proof is empty or does not validate correctly.
    error InvalidMerkleProof();

    /// @dev Thrown when a claim attempt is made after the claim period has ended.
    error ClaimPeriodCompleted();

    /// @dev Thrown when the provided Merkle proof does not match the expected value in the Merkle tree.
    error InvalidProof();

    /// @notice Emitted when a user successfully claims their reward.
    /// @param account The address of the account claiming the reward.
    /// @param amount The amount of the reward claimed.
    event ClaimEvent(address indexed account, uint256 amount);

    /// @notice Returns the amount already claimed by the given account.
    /// @param account The address of the account to query.
    /// @return The amount claimed by the account.
    function getClaimed(address account) external view returns (uint256);

    /// @notice Returns the claimable amount for a given account and total amount, verifying the provided Merkle proof.
    /// @param account The address of the account to query.
    /// @param amount The total amount claimed by the account.
    /// @param merkleProof The Merkle proof associated with the account's claim.
    /// @return The claimable amount for the account.
    function getClaimable(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (uint256);

    /// @notice Verifies the Merkle proof for the given account and amount.
    /// @param account The address of the account.
    /// @param amount The total amount claimed by the account.
    /// @param merkleProof The Merkle proof associated with the account's claim.
    /// @return True if the Merkle proof is valid, false otherwise.
    function verifyProof(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (bool);

    /// @notice Allows a user to claim their rewards based on the total amount and the provided Merkle proof.
    /// @param totalAmount The total amount of the claim.
    /// @param merkleProof The Merkle proof associated with the claim.
    function claim(uint256 totalAmount, bytes32[] calldata merkleProof) external;

    /// @notice Pauses the contract, preventing further claims.
    function pause() external;

    /// @notice Unpauses the contract, allowing claims to resume.
    function unpause() external;

    /// @notice Allows the owner to perform an emergency withdrawal of all remaining reward tokens when the contract is paused.
    function emergencyWithdraw() external;
}
