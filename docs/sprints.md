# Modular Priorities

## Phase 1: DETH

### MUST:
- Deposits of ETH on L1 and L2s

### SHOULD:
- Messaging and standard bridge system
- Swap/Mint system into LST
- EigenLayer simplified

### COULD (next Epics/Sprints)
- DEM voting system
- EigenLayer with multiple operators, DEM selection / voting
- Withdrawal flow
- Per-chain bridge custom to minimize slippage
- Canonical bridge for L2 specific
- DUSD implementation / similarities abstraction

## Sprints

#### P1: Deposits contract on L2 for pre-deposits
- Deposits on L2 and L1, mint OFT - OK
  - Determine upgrade policy and other auth processes
  - Determine fees settings system
  - Determine how to close-off system for beta
- Website, Docs, Socials

#### P2: Bridge system into L1 from all L2s
- Sync tokens with Stargate - OK
- Message system with LayerZero - OK
- Rate system design - OK

#### P3: Swap system into LST
- Swap system to mint sfrxETH
- Fees system: deposit, withdrawals, bridge, rewards
- Beta system & mainnet beta deployment
- Small Audit modules: deposits, bridge (consultant)

#### P4: EigenLayer Single Operator Simple system
- Module to restake into an operator
- Generalize code for DUSD solution
- Structure Messenger to also handle withdrawals
- Audit prep
  - [Audit Handbook](https://hackmd.io/sfWNlhdnSHu54bDY7p_S5Q) 
  - [Readiness Checklist](https://github.com/nascentxyz/simple-security-toolkit/blob/main/audit-readiness-checklist.md)

#### P5 Audit 1 on modules deposits, bridge, swap and simple EigenLayer

#### P6 Withdrawals support
- Withdrawals/Claims flow

#### Later
- Modular system for funds using canonical bridge
- StarGate v2
- Points system on deposits
- Pause contract if rate is stale
- Unit test when slippage creates unbalances
- Study level of decentralization / plan