# Hybrid Privacy Pool System

## Overview

The Hybrid Privacy Pool system integrates Privacy Pools with EncryptedERC tokens using a **Relayer Pattern** to solve the ownership problem where `EncryptedERC.privateMint()` requires `onlyOwner` but we need multiple contracts to trigger mints.

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────┐
│  SimpleHybridPool│────│ EncryptedERCRelayer  │────│   EncryptedERC  │
│                 │    │                      │    │                 │
│ - hybridDeposit │    │ - relayPrivateMint   │    │ - privateMint   │
│ - hybridWithdraw│    │ - authorizedCallers  │    │ - privateBurn   │
└─────────────────┘    └──────────────────────┘    └─────────────────┘
```

## Components

### 1. EncryptedERCRelayer

- **Purpose**: Acts as owner of EncryptedERC and relays calls from authorized contracts
- **Key Features**:
  - Owns the EncryptedERC contract
  - Maintains a whitelist of authorized callers
  - Relays `privateMint` calls to EncryptedERC
  - Provides admin functions for EncryptedERC management

### 2. SimpleHybridPool

- **Purpose**: Privacy Pool that automatically mints EncryptedERC on deposit
- **Key Features**:
  - Inherits from PrivacyPool
  - Calls relayer for EncryptedERC minting on deposit
  - Users handle EncryptedERC burning separately on withdrawal

## Deployment & Setup

### Step 1: Deploy Contracts

```solidity
// 1. Deploy or use existing EncryptedERC
EncryptedERC encryptedERC = new EncryptedERC(params);

// 2. Deploy Relayer
EncryptedERCRelayer relayer = new EncryptedERCRelayer(address(encryptedERC));

// 3. Deploy Hybrid Pool
SimpleHybridPool pool = new SimpleHybridPool(
    entrypoint,
    withdrawalVerifier,
    ragequitVerifier,
    asset,
    address(relayer)
);
```

### Step 2: Configure System

```solidity
// 1. Transfer EncryptedERC ownership to relayer
encryptedERC.transferOwnership(address(relayer));

// 2. Authorize pool to call relayer
relayer.setAuthorizedCaller(address(pool), true);

// 3. Set auditor (through relayer)
relayer.setAuditorPublicKey(auditorAddress);

// 4. Enable hybrid mode
pool.setHybridEnabled(true);
```

## User Flow

### Deposit Flow

1. User calls `entrypoint.deposit()` with mint proof
2. Entrypoint calls `pool.hybridDeposit()`
3. Pool performs normal Privacy Pool deposit
4. Pool calls `relayer.relayPrivateMint()`
5. Relayer calls `encryptedERC.privateMint()`
6. User receives both Privacy Pool commitment and EncryptedERC tokens

### Withdrawal Flow

1. **User first calls** `encryptedERC.privateBurn()` directly
2. User calls `pool.hybridWithdraw()` with Privacy Pool proof
3. Pool performs normal Privacy Pool withdrawal
4. User receives ERC20 tokens

## Security Considerations

### Access Control

- **Relayer**: Only owner can authorize/deauthorize callers
- **EncryptedERC**: Relayer is the owner, controls all privileged operations
- **SimpleHybridPool**: Only entrypoint can call deposit functions

### Burn Handling

- Burns are **not** automatic on withdrawal
- Users must call `EncryptedERC.privateBurn()` directly
- This is because `privateBurn` uses `msg.sender` and requires the actual user to call it

### Trust Assumptions

- Users trust the relayer owner to not authorize malicious contracts
- Users trust the relayer to not abuse EncryptedERC ownership
- Consider using a multisig or DAO for relayer ownership

## Benefits

1. **Separation of Concerns**: Each contract has a clear responsibility
2. **Flexibility**: Relayer can serve multiple pools or contracts
3. **Security**: Granular access control through authorization system
4. **Auditability**: Clear call paths and event emissions
5. **Upgradability**: Can authorize new pool versions without changing EncryptedERC

## Limitations

1. **Additional Complexity**: Extra contract and setup steps
2. **Gas Overhead**: Additional relay call adds gas cost
3. **Manual Burns**: Users must handle EncryptedERC burns separately
4. **Trust Dependency**: Relayer owner has significant control

## Events

### EncryptedERCRelayer

- `CallerAuthorized(address indexed caller, bool authorized)`
- `RelayedMint(address indexed user, address indexed caller)`

### SimpleHybridPool

- `HybridDeposit(address indexed user, uint256 indexed commitment, uint256 amount)`
- `HybridWithdraw(address indexed user, uint256 amount)`
