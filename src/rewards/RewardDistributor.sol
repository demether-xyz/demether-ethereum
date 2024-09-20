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

    /// @notice Campaign structure to track start and end blocks
    struct Campaign {
        uint256 startBlock;
        uint256 endBlock;
        bool isActive;
    }

    /// @notice Mapping of campaigns by their ID
    mapping(uint256 => Campaign) public campaigns;

    /// @notice Counter to track campaign IDs
    uint256 public campaignCounter;

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

    /// @notice Emitted when a campaign is started
    /// @param campaignId The ID of the started campaign
    /// @param startBlock The block number when the campaign started
    event CampaignStarted(uint256 campaignId, uint256 startBlock);

    /// @notice Emitted when a campaign is stopped
    /// @param campaignId The ID of the stopped campaign
    /// @param endBlock The block number when the campaign ended
    event CampaignStopped(uint256 campaignId, uint256 endBlock);

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

    /// @notice Starts a new campaign by recording the current block number as the startBlock
    /// @return campaignId The ID of the started campaign
    function startCampaign() external onlyService returns (uint256 campaignId) {
        campaignId = campaignCounter++;
        require(!campaigns[campaignId].isActive, "Campaign already active");

        campaigns[campaignId] = Campaign({ startBlock: block.number, endBlock: 0, isActive: true });

        emit CampaignStarted(campaignId, block.number);
    }

    /// @notice Stops an active campaign by storing the current block as the endBlock
    /// @param campaignId The ID of the campaign to stop
    function stopCampaign(uint256 campaignId) external onlyService {
        require(campaigns[campaignId].isActive, "Campaign not active");
        campaigns[campaignId].endBlock = block.number;
        campaigns[campaignId].isActive = false;

        emit CampaignStopped(campaignId, block.number);
    }

    /// @notice Returns all the data for a specific campaign
    /// @param campaignId The ID of the campaign
    /// @return startBlock The start block of the campaign
    /// @return endBlock The end block of the campaign
    /// @return isActive The active status of the campaign
    function getCampaignData(uint256 campaignId) external view returns (uint256 startBlock, uint256 endBlock, bool isActive) {
        Campaign memory campaign = campaigns[campaignId];

        require(campaign.startBlock != 0, "Campaign has not started");

        return (campaign.startBlock, campaign.endBlock, campaign.isActive);
    }

    /// @dev Authorizes upgrades of the contract
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        require(_newImplementation.code.length > 0, "New implementation must be a contract");
    }
}
