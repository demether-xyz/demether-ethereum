// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/rewards/RewardDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "murky/src/Merkle.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract RewardDistributorTest is Test {
    RewardDistributor public distributor;
    MockERC20 public token;
    Merkle public merkle;
    address public owner;
    address[] public users;
    uint256[] public amounts;
    bytes32 public merkleRoot;

    function setUp() public {
        owner = address(this);
        token = new MockERC20();
        merkle = new Merkle();

        // Set up users and amounts
        users = new address[](3);
        amounts = new uint256[](3);
        for (uint i = 0; i < 3; i++) {
            users[i] = address(uint160(i + 1));
            amounts[i] = (i + 1) * 1000 * 10 ** 18;
        }

        // Generate Merkle root
        bytes32[] memory leaves = new bytes32[](users.length);
        for (uint i = 0; i < users.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(users[i], amounts[i]));
        }
        merkleRoot = merkle.getRoot(leaves);

        // Deploy the implementation contract
        RewardDistributor implementationContract = new RewardDistributor();

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            RewardDistributor.initialize.selector,
            IERC20Upgradeable(address(token)),
            merkleRoot,
            owner,
            owner
        );

        // Deploy the proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementationContract), address(proxyAdmin), initData);

        // Create a contract instance of RewardDistributor that points to the proxy
        distributor = RewardDistributor(address(proxy));

        // Transfer tokens to the distributor
        token.transfer(address(distributor), 100000 * 10 ** 18);
    }

    function test_Rewards_Initialization() public {
        assertEq(address(distributor.token()), address(token));
        assertEq(distributor.merkleRoot(), merkleRoot);
    }

    function test_Rewards_UpdateMerkleRoot() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        distributor.updateMerkleRoot(newRoot);
        assertEq(distributor.merkleRoot(), newRoot);
    }

    function test_Rewards_ClaimRewards() public {
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 amount = amounts[i];

            bytes32[] memory leaves = new bytes32[](users.length);
            for (uint j = 0; j < users.length; j++) {
                leaves[j] = keccak256(abi.encodePacked(users[j], amounts[j]));
            }
            bytes32[] memory proof = merkle.getProof(leaves, i);

            uint256 initialUserBalance = token.balanceOf(user);
            uint256 initialContractBalance = token.balanceOf(address(distributor));

            vm.prank(user);
            distributor.claim(amount, proof);

            assertEq(token.balanceOf(user), initialUserBalance + amount);
            assertEq(token.balanceOf(address(distributor)), initialContractBalance - amount);
            assertEq(distributor.claimed(user), amount);
        }
    }

    function test_Rewards_FailClaimTwice() public {
        address user = users[0];
        uint256 amount = amounts[0];

        bytes32[] memory leaves = new bytes32[](users.length);
        for (uint i = 0; i < users.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(users[i], amounts[i]));
        }
        bytes32[] memory proof = merkle.getProof(leaves, 0);

        vm.startPrank(user);
        distributor.claim(amount, proof);
        vm.expectRevert("No new tokens to claim");
        distributor.claim(amount, proof); // This should fail
        vm.stopPrank();
    }

    function test_Rewards_WithdrawToken() public {
        uint256 withdrawAmount = 50000 * 10 ** 18;
        uint256 initialOwnerBalance = token.balanceOf(owner);
        uint256 initialContractBalance = token.balanceOf(address(distributor));

        distributor.withdrawToken(withdrawAmount);

        assertEq(token.balanceOf(owner), initialOwnerBalance + withdrawAmount);
        assertEq(token.balanceOf(address(distributor)), initialContractBalance - withdrawAmount);
    }

    function test_Rewards_FailWithdrawTooMuch() public {
        uint256 tooMuch = token.balanceOf(address(distributor)) + 1; // More than the contract balance
        vm.expectRevert("Insufficient balance");
        distributor.withdrawToken(tooMuch);
    }

    function test_Rewards_PauseUnpause() public {
        distributor.pause();
        assertTrue(distributor.paused());

        distributor.unpause();
        assertFalse(distributor.paused());
    }

    function test_Rewards_FailClaimWhenPaused() public {
        distributor.pause();

        address user = users[0];
        uint256 amount = amounts[0];

        bytes32[] memory leaves = new bytes32[](users.length);
        for (uint i = 0; i < users.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(users[i], amounts[i]));
        }
        bytes32[] memory proof = merkle.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        distributor.claim(amount, proof); // This should fail
    }
}
