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
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableAccessControl } from "../OwnableAccessControl.sol";
import { MerkleProofUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title RewardDistributor2
/// @notice This contract manages the distribution of rewards using a Merkle tree for efficient verification
/// @dev This contract is upgradeable, pausable, and uses a Merkle tree for reward distribution
contract RewardDistributor is Initializable, OwnableAccessControl, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    /// @notice The ERC20 token used for rewards
    IERC20Upgradeable public token;

    /// @notice The Merkle root of the reward distribution tree
    bytes32 public merkleRoot;

    /// @notice Mapping to track claimed amounts for each address
    mapping(address => uint256) public claimed;

    /// @notice Emitted when a user claims their reward
    /// @param account The address of the user claiming the reward
    /// @param amount The amount of tokens claimed
    event Claimed(address indexed account, uint256 amount);

    /// @notice Emitted when the Merkle root is updated
    /// @param newMerkleRoot The new Merkle root
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    /// @notice Emitted when tokens are withdrawn from the contract
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _token The address of the ERC20 token used for rewards
    /// @param _merkleRoot The initial Merkle root
    /// @param _owner Owner address with admin privileges
    /// @param _service Service address for contract control
    function initialize(IERC20Upgradeable _token, bytes32 _merkleRoot, address _owner, address _service) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __OwnableAccessControl_init(_owner, _service);

        token = _token;
        merkleRoot = _merkleRoot;
    }

    /// @notice Allows users to claim their rewards
    /// @param totalAmount The total amount of tokens allocated to the user
    /// @param merkleProof The Merkle proof for verification
    function claim(uint256 totalAmount, bytes32[] calldata merkleProof) external nonReentrant whenNotPaused {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalAmount));
        require(MerkleProofUpgradeable.verify(merkleProof, merkleRoot, leaf), "Invalid merkle proof");

        uint256 claimableAmount = totalAmount - claimed[msg.sender];
        require(claimableAmount > 0, "No new tokens to claim");

        claimed[msg.sender] += claimableAmount;

        require(token.transfer(msg.sender, claimableAmount), "Transfer failed");

        emit Claimed(msg.sender, claimableAmount);
    }

    /// @notice Updates the Merkle root
    /// @param _merkleRoot The new Merkle root
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /// @notice Allows the owner to withdraw a specified amount of the reward token from the contract
    /// @param amount The amount of tokens to withdraw
    function withdrawToken(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= token.balanceOf(address(this)), "Insufficient balance");
        require(token.transfer(owner(), amount), "Transfer failed");
        emit TokensWithdrawn(amount);
    }

    /// @notice Pauses all claim operations
    function pause() external onlyService whenNotPaused {
        _pause();
    }

    /// @notice Resumes all claim operations
    function unpause() external onlyService whenPaused {
        _unpause();
    }

    /// @dev Authorizes upgrades of the contract
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "New implementation must be a contract");
    }
}
