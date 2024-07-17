# Demether

Demether is a cutting-edge multichain protocol designed to maximize yield across different blockchain networks. By
leveraging a sophisticated blend of restaking, stablecoins, and other financial derivatives, Demether ensures efficient
and secure high-yield opportunities for its users.

## Features

- **Cross-Chain Deposits**: Users can deposit ETH on both Layer 1 and Layer 2 blockchains.
- **StarGate Bridge**: ETH is transferred between Layer 1 and Layer 2 using the StarGate v1.
- **Yield Generation**: Deposits are allocated into sfrxETH and into EigenLayer LST deposits by a public call
- **EigenLayer Operator**: Single operator for the EigenLayer staking strategy supported.
- **Rate Syncing**: Rates are synced between Layer 1 and Layer 2 chains by public call.

## Architecture

### DOFT.sol

The DETH token, based on the DOFT standard, offers upgradability and cross-chain transferability via LayerZero
technology. It uses a proxy contract pattern for seamless logic upgrades and supports efficient cross-chain
communication to optimize gas costs. Compliant with the ERC-20 standard, it includes essential functions for balance
management and transfers.

- **UUPS upgradable**: Allows for easy contract upgrades.
- **Mintable/Burnable by DepositsManager**: Controlled minting and burning of tokens.

### DepositsManager.sol

- **User Deposits Interface**: Main entry point for user deposits in the Demether protocol.
- **L1 and L2 Coordination**: Ensures seamless communication between Layer 1 and Layer 2 blockchains.
- **Deposit Management**: Efficiently handles the flow of user deposits.
- **High-Yield Optimization**: Allocates assets into high-yield strategies for maximum returns.
- **Funds in WETH**: User deposits are held in Wrapped Ether (WETH) for compatibility and liquidity.

#### DepositsManager L1 Flows

- Users deposit ETH/WETH and mint DETH.

#### DepositsManager L2 Flows

- Users deposit ETH/WETH and mint DETH.

### LiquidityPool.sol

The LiquidityPool contract manages ETH deposits, mints shares for added liquidity, and determines the global rate based
on the total pooled ETH and issued shares. It ensures secure handling of funds and accurate rate reporting while
allowing only authorized management through a designated deposits manager.

- **ETH Management**: Holds and manages ETH funds, determining the global rate for liquidity.
- **Add Liquidity**: Allows the addition of liquidity by minting shares based on received ETH.
- **Rate Determination**: Provides a function to get the current rate of the pool based on total pooled ETH and total
  shares.

#### sfrxETH Strategy

- **Staking Strategy**: Implements a staking strategy to mint sfrxETH tokens.

### Messenger.sol

The Messenger module handles the transfer of ETH and messages cross-chain. It implements LayerZero and StarGate as
standard methods while allowing for specific canonical implementation or expansion of other services.

## Processes

### Sync Rate on L2 Chains

The liquid token rates originate from the L1 chain and are propagated to the L2 chains. The rate is used to determine
the amount of liquid tokens to mint when a user deposits ETH. To avoid staleness of the rate on any L2, if the rate has
not been updated after a given time, the contract will not allow further deposits or withdrawals until a new rate is
synced.

To update the rate, call `syncRate()` on `DepositsManagerL1.sol`, providing the `chainId` and the appropriate gas fees.

### Sync Tokens from L2 Chains to L1

The syncTokens() function on DepositsManagerL2.sol allows users to sync tokens from L2 to L1. This function requires
paying gas fees, which can be quoted by calling quoteLayerZero() on Messenger.sol.

### Add Liquidity and Mint sfrxETH

Deposits from both L1 and L2 remain in the DepositsManager contract. A public call to addLiquidity() initiates the
process of moving the funds to the pool, minting sfrxETH, and staking into EigenLayer.
