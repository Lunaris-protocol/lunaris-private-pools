<div align="center">
  <img src="images/logo.svg" alt="Lunaris Logo" width="400"/>
</div>

# Lunaris Protocol - Privacy Pools Hybrid System

Professional implementation of the **Lunaris Privacy Protocol** - a revolutionary dual-layer privacy solution combining commitment-based mixing with encrypted balance management, featuring automated relayer infrastructure for seamless user experience.

## System Overview

The Lunaris Protocol provides users with **three complementary layers of privacy and automation**:

1. **Privacy Pools Layer**: Commitment-based privacy for deposits/withdrawals with ASP compliance
2. **Encrypted ERC Layer**: Encrypted balance management for private transfers and holdings
3. **Automated Relayer Layer**: Seamless transaction relaying for gasless and private operations

When users interact with Lunaris Protocol, they benefit from:

- **Privacy Pool commitments** for anonymous withdrawals
- **Encrypted ERC tokens** for private transfers
- **Automated relayers** for gasless minting and seamless UX

## Project Structure

```
privacy-pools-core/packages/
├── circuits/                    # Zero-knowledge circuits
├── contracts/                   # Smart contracts (main package)
│   ├── src/contracts/hybrid/    # HYBRID CONTRACTS
│   ├── script/hybrid/           # DEPLOYMENT SCRIPTS
│   ├── test/hybrid/             # COMPREHENSIVE TESTS
│   └── foundry.toml             # Foundry configuration
├── encrypted-erc/               # ENCRYPTED ERC CONTRACTS
├── relayer/                     # Transaction relayer service
└── sdk/                        # TypeScript SDK
```

## Hybrid System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      LUNARIS PROTOCOL                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │   ERC20 Token   │    │  Privacy Pool   │    │   EERC Token │ │
│  │                 │    │                 │    │              │ │
│  │ • Public        │◄──►│ • Commitments   │◄──►│ • Encrypted  │ │
│  │ • Transparent   │    │ • ZK Proofs     │    │ • Private    │ │
│  │ • Regulated     │    │ • Mixing        │    │ • Transfer   │ │
│  └─────────────────┘    └─────────────────┘    └──────────────┘ │
│           │                       │                      │      │
│           └───────────────────────┼──────────────────────┘      │
│                                   │                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              HYBRID ORCHESTRATOR                            │ │
│  │  • Coordinates both systems                                 │ │
│  │  • Ensures balance consistency                              │ │
│  │  • Manages atomic operations                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                   │                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               AUTOMATED RELAYER                             │ │
│  │  • Gasless transactions for users                          │ │
│  │  • Automated minting/burning                               │ │
│  │  • Enhanced privacy through indirection                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### Smart Contracts (`contracts/src/contracts/hybrid/`)

**SimpleHybridPool.sol**

- Extends standard PrivacyPool with hybrid functionality
- `hybridDeposit()` - Performs deposit + automatic EERC minting
- `hybridWithdraw()` - Performs withdrawal + automatic EERC burning
- `setHybridEnabled()` - Toggle hybrid mode per pool
- Maintains 100% backward compatibility

**HybridPoolController.sol**

- Advanced orchestrator for complex hybrid operations
- Multi-asset support and batch operations
- Enhanced security and monitoring capabilities

**EncryptedERCRelayer.sol**

- Automated relayer for gasless minting operations
- Handles encrypted ERC token operations seamlessly
- Provides enhanced privacy through transaction indirection
- Integrates with hybrid system for coordinated operations

### Zero-Knowledge Circuits (`circuits/`)

**commitment.circom**

- Generates commitments for Privacy Pool deposits
- Uses Poseidon hash function for efficiency
- Supports precommitment hashes for enhanced privacy

**merkleTree.circom**

- Merkle tree operations for Privacy Pool state
- Efficient inclusion/exclusion proofs
- Optimized for gas cost and verification speed

**withdraw.circom**

- Withdrawal proof generation for Privacy Pool
- Validates commitment ownership and nullifier uniqueness
- Ensures proper withdrawal authorization

### Encrypted ERC System (`encrypted-erc/`)

**Core Contracts**

- `EncryptedERC.sol` - Main encrypted token contract
- `EncryptedUserBalances.sol` - Encrypted balance management
- `Registrar.sol` - User registration and key management

**Verifiers**

- `MintVerifier.sol` - Mint operation proof verification
- `BurnVerifier.sol` - Burn operation proof verification
- `TransferVerifier.sol` - Transfer operation proof verification

## User Flows

### Deposit Flow (With Automated Relayer)

```mermaid
sequenceDiagram
    participant U as User
    participant S as SDK
    participant R as EncryptedERC Relayer
    participant E as Entrypoint
    participant P as Privacy Pool
    participant EERC as Encrypted ERC
    participant V as Verifiers

    U->>S: Initiate deposit
    S->>S: Generate mint proof
    S->>R: Request gasless mint
    R->>R: Validate request
    R->>E: hybridDeposit(ERC20 + mintProof)
    E->>P: Create commitment
    P->>P: Store tokens
    P->>EERC: privateMint(user, mintProof)
    EERC->>V: Verify mint proof
    V-->>EERC: Proof valid
    EERC-->>P: Mint successful
    P-->>E: Commitment created
    E-->>R: Return commitment
    R-->>S: Relay response
    S-->>U: Deposit complete (gasless!)
```

**Process:**

1. User initiates deposit through SDK with mint proof
2. EncryptedERC Relayer handles gasless transaction execution
3. Privacy Pool creates commitment and stores tokens
4. EncryptedERC automatically mints equivalent tokens
5. User receives both commitment and encrypted tokens **without paying gas**

### Private Transfer Flow

```mermaid
sequenceDiagram
    participant A as Alice
    participant EERC as Encrypted ERC
    participant B as Bob

    A->>EERC: privateTransfer(encryptedAmount, recipient)
    EERC->>EERC: Update encrypted balances
    EERC->>EERC: Verify balance consistency
    EERC-->>B: Encrypted tokens received
    Note over A,B: No public trace of transfer
```

**Privacy Benefits:**

- Transfer amounts are encrypted
- User balances are encrypted
- Only sender and receiver know transaction details
- No public blockchain trace

### Withdrawal Flow

```mermaid
sequenceDiagram
    participant U as User
    participant S as SDK
    participant E as Entrypoint
    participant P as Privacy Pool
    participant EERC as Encrypted ERC
    participant V as Verifiers

    U->>S: Initiate withdrawal
    S->>S: Generate withdrawal + burn proofs
    S->>E: hybridWithdraw(withdrawal + poolProof + burnProof)
    E->>P: Verify withdrawal proof
    P->>V: Validate pool proof
    V-->>P: Pool proof valid
    P->>EERC: privateBurn(burnProof, balancePCT)
    EERC->>V: Verify burn proof
    V-->>EERC: Burn proof valid
    EERC-->>P: Burn successful
    P->>U: Return ERC20 tokens
    P-->>E: Withdrawal complete
    E-->>S: Success
    S-->>U: Withdrawal complete
```

**Process:**

1. User provides ZK proofs for both Privacy Pool and EERC
2. Privacy Pool validates withdrawal proof
3. EncryptedERC burns tokens using burn proof
4. Privacy Pool processes withdrawal and returns ERC20 tokens

## Privacy Comparison

### Privacy Levels by System

| Privacy Aspect              | Standard ERC20 | Privacy Pool Only | EERC Only | **Hybrid System** |
| --------------------------- | -------------- | ----------------- | --------- | ----------------- |
| **Transfer Amount**         | Public         | Public            | Private   | **Private**       |
| **Sender Identity**         | Public         | Public            | Private   | **Private**       |
| **Recipient Identity**      | Public         | Public            | Private   | **Private**       |
| **Balance Privacy**         | Public         | Public            | Private   | **Private**       |
| **Deposit/Withdrawal Link** | Public         | Private           | Public    | **Private**       |
| **Transaction History**     | Public         | Public            | Private   | **Private**       |
| **Regulatory Compliance**   | Yes            | Yes               | No        | **Yes**           |

### Visual Privacy Comparison

```
STANDARD ERC20:
┌─────────────────────────────────────────────────────────────────┐
│ PUBLIC INFORMATION:                                             │
│ • Transfer amounts                                              │
│ • Sender addresses                                              │
│ • Recipient addresses                                           │
│ • Transaction timestamps                                        │
│ • Balance history                                               │
│ • Transaction graph                                             │
│                                                                 │
│ PRIVATE INFORMATION:                                            │
│ • Nothing                                                       │
└─────────────────────────────────────────────────────────────────┘

PRIVACY POOL ONLY:
┌─────────────────────────────────────────────────────────────────┐
│ PUBLIC INFORMATION:                                             │
│ • Deposit amounts                                               │
│ • Withdrawal amounts                                            │
│ • Transaction timestamps                                        │
│ • Pool statistics                                               │
│                                                                 │
│ PRIVATE INFORMATION:                                            │
│ • Connection between deposits and withdrawals                  │
│ • User identity in pool                                        │
└─────────────────────────────────────────────────────────────────┘

ENCRYPTED ERC ONLY:
┌─────────────────────────────────────────────────────────────────┐
│ PUBLIC INFORMATION:                                             │
│ • Nothing                                                       │
│                                                                 │
│ PRIVATE INFORMATION:                                            │
│ • All transfer amounts                                          │
│ • All sender/recipient addresses                                │
│ • All balance information                                       │
│ • Complete transaction history                                  │
│ • No regulatory compliance                                      │
└─────────────────────────────────────────────────────────────────┘

HYBRID SYSTEM (OUR SOLUTION):
┌─────────────────────────────────────────────────────────────────┐
│ PUBLIC INFORMATION:                                             │
│ • Deposit events (amounts, timestamps)                         │
│ • Withdrawal events (amounts, timestamps)                      │
│ • Pool statistics                                               │
│ • Regulatory compliance data                                   │
│                                                                 │
│ PRIVATE INFORMATION:                                            │
│ • All transfer amounts                                          │
│ • All sender/recipient addresses                                │
│ • All balance information                                       │
│ • Connection between deposits and withdrawals                  │
│ • Complete transaction history                                  │
│ • User identity in both systems                                │
└─────────────────────────────────────────────────────────────────┘
```

## Technical Specifications

### Gas Cost Analysis

| Operation | Standard Privacy Pool | Hybrid System | Lunaris + Relayer | User Cost |
| --------- | --------------------- | ------------- | ----------------- | --------- |
| Deposit   | ~150k gas             | ~350k gas     | ~400k gas         | **0 gas** |
| Withdraw  | ~300k gas             | ~700k gas     | ~750k gas         | ~750k gas |
| Transfer  | N/A                   | ~150k gas     | ~180k gas         | **0 gas** |
| Mint      | N/A                   | N/A           | ~200k gas         | **0 gas** |

**Cost Breakdown:**

- Privacy Pool operations: ~150k-300k gas
- EncryptedERC minting/burning: ~150k gas
- Additional coordination: ~50k gas
- Storage operations: ~50k gas
- **Relayer operations: ~50k gas (absorbed by protocol)**
- **User gas cost: 0 for most operations** ✨

### Security Model

```
TRUST ASSUMPTIONS:
├── ZK Verifiers (trusted circuits)
├── Privacy Pool Entrypoint (trusted entry)
├── EncryptedERC Registrar (trusted registration)
├── Hybrid Pool Contract (privileged coordinator)
└── EncryptedERC Relayer (trusted transaction relay)

SECURITY GUARANTEES:
├── Balance Consistency (orchestrator ensures)
├── Atomic Operations (all-or-nothing)
├── Proof Validity (all ZK proofs verified)
├── Authorization (only approved operations)
└── Gasless Security (relayer cannot manipulate user funds)
```

### Attack Vectors & Mitigations

| Attack Vector               | Mitigation                                  |
| --------------------------- | ------------------------------------------- |
| **Invalid Proofs**          | Dual verification, circuit audits           |
| **State Desynchronization** | Atomic operations, comprehensive validation |
| **Gas Griefing**            | Gas limits, efficient implementations       |
| **Reentrancy**              | Reentrancy guards, proper state management  |

## Quick Start

### Prerequisites

- Node.js 18+
- Foundry (for contract development)
- Yarn package manager
- Docker (for relayer services)

### Installation

```bash
# Clone the Lunaris Protocol repository
git clone https://github.com/Lunaris-protocol/lunaris-private-pools.git
cd lunaris-private-pools/packages

# Install dependencies
yarn install

# Build all packages
yarn build
```

### Development

```bash
# Navigate to contracts directory
cd contracts

# Compile contracts
forge build

# Run all hybrid tests including relayer tests
forge test --match-contract HybridTest -vvv

# Test coverage
forge coverage --match-contract Hybrid

# Start relayer service locally
cd ../relayer
docker-compose up -d

# Test relayer integration
yarn test:integration
```

### Deployment

```bash
# Set environment variables
export PRIVATE_KEY="your_private_key"
export RPC_URL="https://api.avax-test.network/ext/bc/C/rpc"

# Deploy complete Lunaris Protocol system with relayer
forge script script/DeployHybridSystem.s.sol:DeployHybridSystem --broadcast --verify

# Deploy and configure relayer
cd ../relayer
cp config.example.json config.json
# Edit config.json with deployed contract addresses

# Start relayer service
docker-compose up -d

# Check system status
forge script script/hybrid/Interact.s.sol:Interact --sig "checkStatus()"
```

## Testing Strategy

### Test Categories

**Unit Tests**

- Individual contract functionality
- Edge cases and error conditions
- Gas optimization verification

**Integration Tests**

- End-to-end system flows
- Cross-contract interactions
- Multi-user scenarios

**Security Tests**

- Attack vector coverage
- Reentrancy protection
- Access control validation

### Key Test Scenarios

- End-to-end deposit with encrypted minting
- End-to-end withdrawal with coordinated burning
- Multi-user scenarios with different assets
- Security edge cases and attack prevention
- Gas optimization verification
- Backward compatibility validation

## Configuration

### Required Contracts

- Privacy Pools Entrypoint
- Privacy Pool verifiers (withdrawal, ragequit)
- EncryptedERC components (registrar, verifiers)
- ERC20 tokens to support

### System Parameters

- Minimum deposit amounts per asset
- Fee structures (vetting fees, relay fees)
- Tree depth limits
- Gas limits

### Environment Variables

```bash
# Deployment
PRIVATE_KEY=your_deployer_private_key
RPC_URL=your_rpc_endpoint
ETHERSCAN_API_KEY=your_api_key

# Network specific
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
AVALANCHE_RPC_URL=https://api.avax.network/ext/bc/C/rpc
```

## Performance Optimization

### Optimization Strategies

```
1. BATCH OPERATIONS
   • Multiple deposits in single transaction
   • Batch proof verification
   • Reduced gas overhead per operation

2. EFFICIENT PROOF GENERATION
   • Optimized circuit design
   • Parallel proof computation
   • Cached intermediate results

3. SMART CONTRACT OPTIMIZATIONS
   • Minimal storage operations
   • Efficient data structures
   • Gas-optimized algorithms

4. LAYER 2 INTEGRATION
   • Rollup-based scaling
   • Reduced on-chain gas costs
   • Faster transaction processing
```

## Integration Guide

### For DApp Developers

- Standard deposits work unchanged
- For hybrid withdrawals, use `withdrawWithBurn()` with both ZK proofs
- Query both systems for complete user state

### For Protocol Integrators

- Extend `SimpleHybridPool` and `EncryptedERC`
- Deploy and configure hybrid orchestrator
- Set up proper authorization chains

## Documentation

- [Contracts README](contracts/README.md) - Smart contracts documentation
- [Hybrid Contracts](contracts/src/contracts/hybrid/README.md) - Hybrid system specifics
- [Circuits](circuits/README.md) - Zero-knowledge circuits
- [SDK](sdk/README.md) - Developer SDK
- [Relayer](relayer/README.md) - Transaction relayer

## Contributing

1. Follow existing code standards and structure
2. Add comprehensive tests for new features
3. Update documentation
4. Ensure backward compatibility
5. Consider gas optimization

## Production Checklist

Before mainnet deployment:

- [ ] Complete security audit
- [ ] Gas optimization review
- [ ] Integration testing with real verifiers
- [ ] Multi-signature orchestrator setup
- [ ] Emergency procedures documented
- [ ] Monitoring and alerting configured

---

**Result**: Users get triple-layer privacy combining privacy pool mixing, encrypted balance management, and gasless transactions through automated relayers - all in a single, seamless protocol.

---

## 🔗 Lunaris Protocol Links

- [Website](https://lunaris.dev)
- [Documentation](https://docs.lunaris.dev)
- [GitHub](https://github.com/Lunaris-protocol)
- [Discord](https://discord.gg/lunaris)
- [Twitter](https://twitter.com/lunaris_dev)

**Contact**: For questions or support, open an issue in this repository or join our Discord community.
