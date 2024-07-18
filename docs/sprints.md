# Modular Priorities

## Phase 1: DETH

### MUST:
- Multi-sig for institutional deposits + EG points
  - Transfer existing positions in EG
- Deposits of ETH on L1 and L2s
  - Whitelist system
  - Referral system to get into whitelist

### SHOULD:
- Messaging and standard bridge system
- Swap/Mint system into LST
- EigenLayer simplified

### COULD (next Epics/Sprints)
- EigenLayer with multiple operators, DEM selection / voting
- Withdrawal flow
- DUSD implementation / similarities abstraction
- DEM voting system
- Canonical bridge for L2 specific

## Backlog
- Revise StarGate v2 with docs
- EigenLayer delegate into a single operator
- Pause contract if rate is stale
- Handle frax/EG axternal calls try/catch - Discussing
- frxETh how to convert into ETH / account for price changes - WIP

#### PX Audit 1 on modules deposits, bridge, swap and simple EigenLayer
- Verify items in `Later` that need addressing and `TODO`
- Beta system & mainnet beta deployment
- Small Audit modules: deposits, bridge (consultant)
- Audit prep
  - [Audit Handbook](https://hackmd.io/sfWNlhdnSHu54bDY7p_S5Q)
  - [Readiness Checklist](https://github.com/nascentxyz/simple-security-toolkit/blob/main/audit-readiness-checklist.md)

## Completed
- Deposits on L2 and L1, mint OFT - OK
- Sync tokens with Stargate - OK
- Message system with LayerZero - OK
- Rate system design - OK
- Stake system to mint sfrxETH - OK
- Fees: rewards fee system - OK
- Unit test when slippage creates unbalances - OK
- EigenLayer deposit into StrategyManager - OK

#### PX: Withdrawals support
- Withdrawals/Claims flow
- Structure Messenger to also handle withdrawals

#### Later
- Modular system for funds using canonical bridge
- StarGate v2
- Study level of decentralization / plan
- Discuss feature to accept OFT tokens / sfrxETH
- EigenLayer system of contracts to delegate into several operators