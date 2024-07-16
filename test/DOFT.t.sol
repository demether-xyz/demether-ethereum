// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "lib/forge-std/src/Test.sol";
import { DOFT } from "../src/DOFT.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DOFTTest is Test {
    DOFT public doft;
    DOFT public newDoftImplementation;
    ERC1967Proxy public proxy;
    DOFT public doftProxy;

    address public owner = address(1);
    address public user = address(2);
    address public user1 = address(3);
    address public user2 = address(4);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    // Example LayerZero endpoint address on mainnet
    address public layerZeroEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");

    // the identifiers of the forks
    uint256 public mainnetFork;

    string public rpcUrl = vm.envString("RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(rpcUrl);
        // Deploy the DOFT contract implementation
        vm.prank(owner);
        doft = new DOFT(layerZeroEndpoint);
        doft.initialize("Test Token", "TT", owner);

        // Deploy the proxy pointing to the implementation
        vm.prank(owner);
        proxy = new ERC1967Proxy(
            address(doft),
            abi.encodeWithSelector(DOFT.initialize.selector, "Test Token", "TT", owner)
        );

        // Point DOFT proxy to the proxy address
        doftProxy = DOFT(address(proxy));
    }

    function testInitialize() public view {
        assertEq(doftProxy.name(), "Test Token");
        assertEq(doftProxy.symbol(), "TT");
        assertEq(doftProxy.owner(), owner);
    }

    function testMint() public {
        vm.prank(owner);
        doftProxy.mint(user, 1000);

        assertEq(doftProxy.balanceOf(user), 1000);
    }

    function testBurn() public {
        vm.prank(owner);
        doftProxy.mint(user, 1000);

        vm.prank(owner);
        doftProxy.burn(user, 500);

        assertEq(doftProxy.balanceOf(user), 500);
    }

    function testUnauthorizedMint() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        doftProxy.mint(user, 1000);
    }

    function testUnauthorizedBurn() public {
        vm.prank(owner);
        doftProxy.mint(user, 1000);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        doftProxy.burn(user, 500);
    }

    function testUpgrade() public {
        // Deploy new implementation
        newDoftImplementation = new DOFT(layerZeroEndpoint);

        // Upgrade the proxy to the new implementation
        vm.prank(owner);
        doftProxy.upgradeToAndCall(address(newDoftImplementation), "");

        // Verify the implementation has been upgraded
        address getImplementation = doftProxy.getImplementation();
        assertEq(address(newDoftImplementation), getImplementation);
    }

    function testUpgradeAndCallMethods() public {
        // mint with old implementation
        vm.prank(owner);
        doftProxy.mint(user, 1000);
        // Deploy new implementation
        newDoftImplementation = new DOFT(layerZeroEndpoint);

        // Upgrade the proxy to the new implementation
        vm.prank(owner);
        doftProxy.upgradeToAndCall(address(newDoftImplementation), "");

        // call transfer with new implementation
        vm.prank(user);
        doftProxy.transfer(user2, 50);
        assertEq(doftProxy.balanceOf(user2), 50);
    }

    function testUnauthorizedUpgrade() public {
        // Deploy new implementation
        newDoftImplementation = new DOFT(layerZeroEndpoint);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        doftProxy.upgradeToAndCall(address(newDoftImplementation), "");
    }

    function testTransfer() public {
        vm.prank(owner);
        doftProxy.mint(user, 1000);
        vm.prank(user);
        doftProxy.transfer(user2, 50);
        assertEq(doftProxy.balanceOf(user2), 50);
    }

    function testTransferFrom() public {
        vm.prank(owner);
        doftProxy.mint(owner, 1000);
        vm.prank(owner);
        doftProxy.approve(user1, 50);
        vm.prank(user1);
        doftProxy.transferFrom(owner, user2, 50);
        assertEq(doftProxy.balanceOf(user2), 50);
    }

    function testApprove() public {
        vm.prank(owner);
        doftProxy.mint(owner, 1000);
        vm.prank(owner);
        doftProxy.approve(user1, 50);
        assertEq(doftProxy.allowance(owner, user1), 50);
    }

    function testTransfeRevert() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, address(user), 0, 1001));
        doftProxy.transfer(user2, 1001);
    }

    function testTransfeFromRevert() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(user), 0, 50));
        doftProxy.transferFrom(owner, user2, 50);
    }
}