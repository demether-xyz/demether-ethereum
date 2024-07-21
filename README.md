# Demether Protocol

## Table of Contents
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Architecture](#architecture)
   - [DOFT (Demether Open Fungible Token)](#doft-demether-open-fungible-token)
   - [DepositsManagerL1](#depositsmanagerl1)
   - [DepositsManagerL2](#depositsmanagerl2)
   - [Messenger](#messenger)
   - [LiquidityPool](#liquiditypool)
4. [Protocol Flow](#protocol-flow)
5. [Key Processes](#key-processes)
   - [Syncing Rate on L2 Chains](#syncing-rate-on-l2-chains)
   - [Syncing Tokens from L2 to L1](#syncing-tokens-from-l2-to-l1)
   - [Adding Liquidity and Minting sfrxETH](#adding-liquidity-and-minting-sfrxeth)
6. [Security Considerations](#security-considerations)

## Overview

Demether is a cutting-edge multichain protocol designed to maximize yield across different blockchain networks. By leveraging a sophisticated blend of restaking, stablecoins, and other financial derivatives, Demether ensures efficient and secure high-yield opportunities for its users. Demether is designed for users seeking to maximize their ETH yields across multiple blockchain layers while minimizing risk and complexity.

## Key Features

1. **Multi-Layer Staking**: Supports ETH staking on both Layer 1 (Ethereum mainnet) and Layer 2 networks.
2. **Cross-Chain Functionality**:
   - Enables seamless transfer of assets and messages between different blockchain networks.
   - Utilizes StarGate Bridge v1 for ETH transfers between Layer 1 and Layer 2.
3. **Yield Optimization**:
   - Utilizes multiple strategies (e.g., frxETH, EigenLayer) to maximize staking returns.
   - Deposits are allocated into sfrxETH and EigenLayer LST deposits.
4. **EigenLayer Integration**:
   - Supports a single operator for the EigenLayer staking strategy.
5. **Liquidity Management**: Efficient handling of user deposits and withdrawals across layers.
6. **Protocol-Owned Liquidity**: Accumulates fees to build protocol-owned liquidity, enhancing sustainability.
7. **Rate Synchronization**: Rates are synced between Layer 1 and Layer 2 chains by public call.
8. **Upgradeable Design**: Allows for future improvements and additions to the protocol.
9. **Flexible Design**: Allows for easy integration of new yield strategies and supported networks in the future.

## Architecture

The Demether protocol consists of several key components:

1. **DOFT (Demether Open Fungible Token)**: ERC20 token representing staked ETH.
2. **DepositsManagerL1**: Manages user deposits on Layer 1.
3. **DepositsManagerL2**: Manages user deposits on Layer 2.
4. **Messenger**: Facilitates cross-chain message and token transfers.
5. **LiquidityPool**: Manages ETH liquidity and staking strategies.


### DOFT (Demether Open Fungible Token)

`DOFT` is an ERC20 token with cross-chain capabilities and upgradability features for the Demether protocol.

#### Key Features

- ERC20 token functionality
- Cross-chain transfer capabilities via LayerZero
- Upgradeable contract design
- Controlled minting and burning

#### Core Functions

1. `initialize(string _name, string _symbol, address _delegate, address _minterAddress)`: Initializes the token with name, symbol, delegate, and minter
2. `mint(address _to, uint256 _amount)`: Mints new tokens to a specified address
3. `burn(address _from, uint256 _amount)`: Burns tokens from a specified address
4. `send(SendParam memory _sendParam, MessagingFee memory _fee, address payable _refundAddress)`: Sends tokens across chains

#### Token Management

- Minting and burning restricted to a designated minter address
- Ownership and upgrade control managed by the contract owner

#### Integration Points

- `OFTUpgradeable`: Provides cross-chain token transfer capabilities
- `UUPSUpgradeable`: Enables contract upgradeability
- LayerZero endpoint: Used for cross-chain messaging

#### Inheritance

- Inherits from `OFTUpgradeable` for cross-chain functionality
- Inherits from `UUPSUpgradeable` for upgrade mechanisms

### DepositsManagerL1

`DepositsManagerL1` manages user deposits on Layer 1 within the Demether protocol, handling deposit reception, cross-chain messaging, and token minting.

#### Key Features

- Accepts ERC-20 and native currency deposits
- Converts ETH to WETH for compatibility
- Mints DETH tokens representing user shares
- Facilitates cross-chain deposits to Layer 2
- Allocates assets to high-yield L1 strategies

#### Core Functions

1. `deposit(uint256 _amountIn, uint32 _chainId, uint256 _fee, address _referral)`: Handles WETH deposits
2. `depositETH(uint32 _chainId, uint256 _fee, address _referral)`: Handles native ETH deposits
3. `getConversionAmount(uint256 _amountIn)`: Calculates DETH tokens to mint
4. `syncRate(uint32[] _chainId, uint256[] _chainFee)`: Synchronizes rates across chains
5. `addLiquidity()`: Adds liquidity to the pool from the contract's balance
6. `getRate()`: Retrieves the current conversion rate from the liquidity pool

#### Deposit Flow

1. User deposits ETH/WETH
2. Funds are converted to WETH if necessary
3. DETH tokens are minted based on current exchange rates
4. For L2 strategies, cross-chain messaging is initiated
5. Funds are allocated to yield-generating strategies

#### Integration Points

- `IDOFT`: Interface for minting DETH tokens
- `ILiquidityPool`: Manages liquidity and provides exchange rates
- `IMessenger`: Handles cross-chain communication
- `IWETH9`: Wraps and unwraps ETH

### DepositsManagerL2

`DepositsManagerL2` manages user deposits on Layer 2 within the Demether protocol, handling deposit reception, cross-chain messaging, and token minting.

#### Key Features

- Accepts ERC-20 and native currency deposits
- Converts ETH to WETH for compatibility
- Mints DOFT tokens representing user shares
- Facilitates cross-chain deposits to Layer 1
- Syncs exchange rates with Layer 1

#### Core Functions

1. `deposit(uint256 _amountIn, uint32 _chainId, uint256 _fee, address _referral)`: Handles WETH deposits
2. `depositETH(uint32 _chainId, uint256 _fee, address _referral)`: Handles native ETH deposits
3. `getConversionAmount(uint256 _amountIn)`: Calculates DOFT tokens to mint
4. `getRate()`: Retrieves the current conversion rate
5. `syncTokens(uint256 _amount)`: Syncs tokens with Layer 1
6. `onMessageReceived(uint32 _chainId, bytes calldata _message)`: Handles incoming messages from Layer 1

#### Deposit Flow

1. User deposits ETH/WETH
2. Funds are converted to WETH if necessary
3. DOFT tokens are minted based on current exchange rates
4. For L1 transfers, cross-chain messaging is initiated
5. Deposit fee is applied for gas and slippage coverage

#### Integration Points

- `IDOFT`: Interface for minting DOFT tokens
- `IMessenger`: Handles cross-chain communication
- `IWETH9`: Wraps and unwraps ETH

#### Rate Management

- Exchange rate synced from Layer 1
- Rate updates tracked by block number

### Messenger

`Messenger` facilitates cross-chain message and token transfers within the Demether protocol, integrating with various bridge protocols.

#### Key Features

- Supports multiple bridge protocols (LayerZero, Stargate)
- Handles cross-chain token transfers
- Manages cross-chain messaging
- Configurable settings for different chains and bridges

#### Core Functions

1. `syncTokens(uint32 _destination, uint256 _amount, address _refund)`: Initiates cross-chain token transfers
2. `syncMessage(uint32 _destination, bytes calldata _data, address _refund)`: Sends messages across chains
3. `lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata)`: Handles incoming LayerZero messages
4. `quoteLayerZero(uint32 _destination)`: Quotes fees for LayerZero messages

#### Configuration Functions

1. `setSettingsMessages(uint32 _destination, Settings calldata _settings)`: Updates message transfer settings
2. `setSettingsTokens(uint32 _destination, Settings calldata _settings)`: Updates token transfer settings
3. `setRouters(uint8[] calldata _bridgeIds, address[] calldata _routers, address _owner)`: Sets router addresses for bridge protocols

#### Integration Points

- `ILayerZeroEndpointV2`: Interface for LayerZero operations
- `IStargateRouterETH`: Interface for Stargate operations
- `IWETH9`: Interface for WETH operations
- `IDepositsManager`: Interface for deposits management

#### Bridge Support

- LayerZero: For cross-chain messaging
- Stargate: For cross-chain token transfers

### LiquidityPool

`LiquidityPool` manages ETH liquidity, staking, and yield strategies within the Demether protocol, integrating with frxETH and EigenLayer.

#### Key Features

- Manages ETH liquidity and share issuance
- Integrates with frxETH for ETH staking
- Utilizes EigenLayer for additional yield strategies
- Handles protocol fees and rewards distribution

#### Core Functions

1. `addLiquidity(bool _process)`: Adds liquidity to the pool and optionally processes it
2. `totalAssets()`: Calculates total assets in the pool
3. `getRate()`: Returns the current exchange rate of shares to ETH
4. `delegateEigenLayer(address _operator)`: Delegates to an operator in EigenLayer

#### Internal Operations

- `_convertToShares(uint256 _deposit)`: Converts deposit amount to shares
- `_mintSfrxETH()`: Mints sfrxETH with available ETH balance
- `_eigenLayerRestake()`: Restakes sfrxETH in EigenLayer

#### Configuration Functions

1. `setFraxMinter(address _fraxMinter)`: Sets the frxETH minter address
2. `setEigenLayer(address _strategyManager, address _strategy, address _delegationManager)`: Sets EigenLayer contracts
3. `setProtocolFee(uint256 _fee)`: Sets the protocol fee
4. `setProtocolTreasury(address payable _treasury)`: Sets the protocol treasury address

#### Integration Points

- `IsfrxETH`: Interface for sfrxETH operations
- `IfrxETHMinter`: Interface for frxETH minting
- `IStrategyManager`, `IStrategy`, `IDelegationManager`: Interfaces for EigenLayer integration

#### Yield Strategies

- frxETH: Primary ETH staking strategy
- EigenLayer: Additional yield through restaking

## Protocol Flow

1. Users deposit ETH (or WETH) into DepositsManagerL1 or DepositsManagerL2.
2. The protocol mints DETH/DOFT tokens representing the user's share.
3. Deposited ETH is sent to the LiquidityPool for yield generation.
4. LiquidityPool stakes ETH using frxETH and potentially restakes using EigenLayer.
5. Yields are accumulated and reflected in the increasing value of DETH/DOFT tokens.
6. Cross-chain operations are facilitated by the Messenger contract using StarGate Bridge.
7. Accumulated yields are periodically distributed, increasing the value of user shares.

## Key Processes

### Syncing Rate on L2 Chains

The liquid token rates originate from the L1 chain and are propagated to the L2 chains. The rate is used to determine the amount of liquid tokens to mint when a user deposits ETH. To avoid staleness of the rate on any L2, if the rate has not been updated after a given time, the contract will not allow further deposits or withdrawals until a new rate is synced.

To update the rate, call `syncRate()` on `DepositsManagerL1.sol`, providing the `chainId` and the appropriate gas fees.

### Syncing Tokens from L2 to L1

The `syncTokens()` function on `DepositsManagerL2.sol` allows users to sync tokens from L2 to L1. This function requires paying gas fees, which can be quoted by calling `quoteLayerZero()` on `Messenger.sol`.

### Adding Liquidity and Minting sfrxETH

Deposits from both L1 and L2 remain in the DepositsManager contract. A public call to `addLiquidity()` initiates the process of moving the funds to the pool, minting sfrxETH, and staking into EigenLayer.

## Security Considerations

- Upgradeable contracts with access control
- Integration with established protocols (frxETH, EigenLayer)
- Cross-chain message verification and security measures
- Regular security audits and open-source code for community review
- Timelocks and multisig controls on critical protocol functions