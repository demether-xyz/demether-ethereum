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
- Stake system to mint sfrxETH - OK
- Fees: rewards fee system - OK
- Unit test when slippage creates unbalances - OK

#### P4: EigenLayer single operator
- Module to restake into an operator

#### P5: Generalization DUSD prep
- Generalize code for DUSD solution
- Fees: deposit, withdrawals to cover bridging costs

#### P6: Deposits requirements
- Whitelist integration / referrals 
- Deposit and mint immediately, without processing / gas based
- Limits on batches sending
- Chains disabling bridging / simpler settings

#### PX Audit 1 on modules deposits, bridge, swap and simple EigenLayer
- Beta system & mainnet beta deployment
- Small Audit modules: deposits, bridge (consultant)
- Audit prep
  - [Audit Handbook](https://hackmd.io/sfWNlhdnSHu54bDY7p_S5Q)
  - [Readiness Checklist](https://github.com/nascentxyz/simple-security-toolkit/blob/main/audit-readiness-checklist.md)

#### PX: Withdrawals support
- Withdrawals/Claims flow
- Structure Messenger to also handle withdrawals

#### Later
- Modular system for funds using canonical bridge
- StarGate v2
- Points system on deposits
- Pause contract if rate is stale
- Study level of decentralization / plan
- Discuss feature to accept OFT tokens / sfrxETH