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

### Sprints Priorities

#### P1: Deposits contract on L2 for pre-deposits
- Deposits on L2 and L1, mint OFT
  - Determine upgrade policy and other auth processes
  - Determine fees settings system
  - Determine how to close-off system for beta
- Rate system design 
- Website, Docs, Socials
- Points system on deposits

#### P2: Bridge system into L1 from all L2s
- Bridge Manager system with Layer Zero + Stargate
- Modular system for funds using canonical bridge

#### P3: Swap system into LST
- Swap system to mint sfrxETH
- Rate system to report rewards and aggregate rate to all L2s
- Integrate rate module in deposits module
- Small Audit modules: deposits, bridge (consultant)

#### P4: EigenLayer Single Operator Simple system
- Module to restake into an operator
- Audit prep

#### P5 Audit 1 on modules deposits, bridge, swap and simple EigenLayer
