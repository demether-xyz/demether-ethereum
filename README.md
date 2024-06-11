# Demether

Demether is a cutting-edge multichain protocol designed to maximize yield across different blockchain networks. By leveraging a sophisticated blend of restaking, stablecoins, and other financial derivatives, Demether ensures efficient and secure high-yield opportunities for its users.

## Architechture

### DOFT.sol

The DETH token, based on the DOFT standard, offers upgradability and cross-chain transferability via LayerZero technology. It uses a proxy contract pattern for seamless logic upgrades and supports efficient cross-chain communication to optimize gas costs. Compliant with the ERC-20 standard, it includes essential functions for balance management and transfers.

- UUPS upgradable
- Mintable/Burnable by DepositsManager

### DepositsManager.sol

- User Deposits Interface: Main entry point for user deposits in the Demether protocol.
- L1 and L2 Coordination: Ensures seamless communication between Layer 1 and Layer 2 blockchains.
- Deposit Management: Efficiently handles the flow of user deposits.
- High-Yield Optimization: Allocates assets into high-yield strategies for maximum returns.
- Funds in WETH: User deposits are held in Wrapped Ether (WETH) for compatibility and liquidity.

#### DepositsManager L1 Flows

- User deposits ETH/WETH and mints DETH

#### DepositsManager L2 Flows

- User deposits ETH/WETH and mints DETH

### LiquidityPool.sol

The LiquidityPool contract manages ETH deposits, mints shares for added liquidity, and determines the global rate based on the total pooled ETH and issued shares. It ensures secure handling of funds and accurate rate reporting while allowing only authorized management through a designated deposits manager.

- ETH Management: Holds and manages ETH funds, determining the global rate for liquidity.
- Add Liquidity: Allows the addition of liquidity by minting shares based on received ETH.
- Rate Determination: Provides a function to get the current rate of the pool based on total pooled ETH and total shares.

### Messenger.sol

Module handles the transfer of ETH and messages cross-chain. Implements LayerZero and StarGate as standard method while allowing for specific canonical implementation or expansion of other services.