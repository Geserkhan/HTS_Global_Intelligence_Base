# pallet-zk-verification

Zero-Knowledge Proof Verification Pallet for AFE Protocol built on Substrate polkadot-v1.0.0

## Overview

This pallet provides zero-knowledge proof verification capabilities for the AFE Protocol, enabling privacy-preserving transactions and operations on the blockchain.

## Features

- **Proof Verification**: Submit and verify zero-knowledge proofs on-chain
- **Nullifier Management**: Prevent double-spending through nullifier tracking
- **Proof Expiration**: Automatic proof expiration after configurable period
- **Admin Controls**: Administrative functions for proof management

## Configuration

### Runtime Configuration

```rust
impl pallet_zk_verification::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type AdminOrigin = EnsureRoot<AccountId>;
    type ProofValidityPeriod = ProofValidityPeriod;
    type MaxProofSize = MaxProofSize;
    type MaxNullifierSetSize = MaxNullifierSetSize;
}
```

### Parameters

- **AdminOrigin**: Origin that can perform administrative operations (Default: Root)
- **ProofValidityPeriod**: Duration in blocks before a proof expires (Default: 5,256,000 blocks ≈ 365 days at 6s/block)
- **MaxProofSize**: Maximum size of a proof in bytes (Default: 2048 bytes)
- **MaxNullifierSetSize**: Maximum number of nullifiers that can be stored (Default: 100,000)

## Mock Runtime

The mock runtime (`src/mock.rs`) provides a test environment for the pallet with the following configuration:

### System Pallet Configuration
- **AccountId**: `u64`
- **BlockNumber**: `u64`
- **Hash**: `H256`
- **Hashing**: `BlakeTwo256`

### ZK Verification Pallet Configuration
- **AdminOrigin**: `EnsureRoot<u64>`
- **ProofValidityPeriod**: 5,256,000 blocks
- **MaxProofSize**: 2048 bytes
- **MaxNullifierSetSize**: 100,000 entries

### Test Helpers

The mock runtime includes several helper functions:

```rust
// Test account IDs
pub const ALICE: u64 = 1;
pub const BOB: u64 = 2;
pub const CHARLIE: u64 = 3;

// Advance blocks
pub fn run_to_block(n: u64);

// Create test proof
pub fn create_test_proof(size: usize) -> Vec<u8>;

// Create test nullifier
pub fn create_test_nullifier(seed: u8) -> H256;
```

## Usage Example

```rust
use frame_support::BoundedVec;

// Create a proof
let proof_data = vec![0u8; 1024];
let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
let nullifier = H256::from([1u8; 32]);

// Submit proof
ZkVerification::submit_proof(
    RuntimeOrigin::signed(ALICE),
    proof,
    nullifier
)?;

// Invalidate expired proof (admin only)
ZkVerification::invalidate_expired_proof(
    RuntimeOrigin::root(),
    proof_hash
)?;
```

## Testing

Run the tests with:

```bash
cargo test --package pallet-zk-verification
```

### Test Coverage

- Mock runtime configuration verification
- Proof submission and verification
- Nullifier uniqueness enforcement
- Proof size limit enforcement
- Proof expiration mechanism
- Admin permission checks
- Multiple proof handling

## Integration

To integrate this pallet into your runtime:

1. Add the dependency to your `Cargo.toml`:

```toml
[dependencies]
pallet-zk-verification = { path = "../../pallets/zk-verification", default-features = false }
```

2. Add the pallet to your runtime:

```rust
construct_runtime!(
    pub enum Runtime {
        // ... other pallets
        ZkVerification: pallet_zk_verification,
    }
);
```

3. Implement the `Config` trait with your desired parameters

## Storage

### Proofs
- **Type**: `StorageMap<Hash, ProofMetadata>`
- **Description**: Stores proof metadata including verifier, submission time, expiration, and validity status

### Nullifiers
- **Type**: `StorageMap<Hash, ()>`
- **Description**: Tracks used nullifiers to prevent double-spending

## Events

- **ProofVerified**: Emitted when a proof is successfully verified
- **NullifierRecorded**: Emitted when a nullifier is recorded
- **ProofExpired**: Emitted when a proof is marked as expired

## Errors

- **ProofTooLarge**: Proof size exceeds maximum allowed
- **NullifierAlreadyExists**: Nullifier already exists (double-spend attempt)
- **ProofNotFound**: Proof does not exist
- **ProofExpired**: Proof has expired
- **NullifierSetFull**: Nullifier set is full
- **InvalidProof**: Invalid proof

## License

Apache-2.0

## Contributing

Contributions are welcome! Please follow the standard GitHub workflow:

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
