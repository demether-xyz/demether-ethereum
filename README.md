# Demether

Demether is a cutting-edge multichain protocol designed to maximize yield across different blockchain networks. By leveraging a sophisticated blend of restaking, stablecoins, and other financial derivatives, Demether ensures efficient and secure high-yield opportunities for its users.

## Architechture

### DOFT

The DETH token, based on the DOFT standard, offers upgradability and cross-chain transferability via LayerZero technology. It uses a proxy contract pattern for seamless logic upgrades and supports efficient cross-chain communication to optimize gas costs. Compliant with the ERC-20 standard, it includes essential functions for balance management and transfers.

- UUPS upgradable
- Mintable/Burnable by DepositsManager

### DepositsManager

The DepositsManager contract is the primary interface for user deposits within the Demether protocol. It acts as a crucial intermediary, facilitating seamless communication and coordination between Layer 1 (L1) and Layer 2 (L2) blockchains, managing deposit flows, and optimizing the deployment of assets into various high-yield strategies.

#### DepositsManager L1 Flows

- User deposits ETH/WETH and mints DETH

#### DepositsManager L2 Flows

- User deposits ETH/WETH and mints DETH