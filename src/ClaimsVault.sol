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

/// @title Claims contract
/// @dev Manages the receive of StartGate or other funds where gas limit is an issue on UUPS contracts
contract ClaimsVault {
    /// @notice Manager of the funds
    address public immutable MANAGER;

    /// @notice Custom errors
    error InvalidAddress();
    error Unauthorized();
    error TransferFailed();

    /// @param _manager Address of the LiquidityPool
    constructor(address _manager) {
        if (_manager == address(0)) revert InvalidAddress();
        MANAGER = _manager;
    }

    /// @notice Allows LiquidityPool to claim any ETH received
    function claimFunds() external {
        if (msg.sender != MANAGER) revert Unauthorized();
        // slither-disable-next-line arbitrary-send-eth,low-level-calls
        (bool sent, ) = MANAGER.call{ value: address(this).balance }("");
        if (!sent) revert TransferFailed();
    }

    /// @notice Receive function to accept ETH transfers
    receive() external payable {}

    /// @notice Fallback function to accept ETH transfers with data
    fallback() external payable {}
}
