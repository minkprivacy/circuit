# Architecture

This document describes the cryptographic architecture of the Mink circuit system — a privacy-preserving UTXO protocol built on Circom 2 with Groth16 proofs, designed for on-chain verification on Solana.

## System Overview

```
                      ┌─────────────────────────────────┐
                      │         Client (off-chain)       │
                      │                                  │
                      │  ┌───────────┐  ┌─────────────┐ │
                      │  │  Witness   │  │   snarkjs    │ │
                      │  │ Generator  │→ │  Prover      │ │
                      │  └───────────┘  └──────┬──────┘ │
                      └────────────────────────┼────────┘
                                               │ proof π
                                               ▼
                      ┌─────────────────────────────────┐
                      │        On-chain Verifier         │
                      │   (Groth16 over BN254 / Solana)  │
                      │                                  │
                      │  Verification Key  ←  circuits/  │
                      └─────────────────────────────────┘
```

The protocol separates **proof generation** (client-side, off-chain) from **proof verification** (on-chain). Circuits define the constraint systems; the prover constructs a witness satisfying those constraints; the verifier checks the proof against a fixed verification key.

## Circuit Dependency Graph

```
circomlib/poseidon ─────────┐
circomlib/bitify ───────┐   │
circomlib/comparators ──┤   │
circomlib/switcher ─────┤   │
                        │   │
                        ▼   ▼
                  ┌─────────────┐
                  │ lib/keypair  │ ← Poseidon-based key derivation
                  │ lib/merkle   │ ← Poseidon-based Merkle proofs
                  └──────┬──────┘
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
   ┌──────────────┐ ┌──────────┐ ┌──────────────┐
   │ stealth_tx   │ │  inbox   │ │ viewing_key  │
   │ (UTXO txns)  │ │ (identity│ │ (audit keys) │
   └──────────────┘ │  proof)  │ └──────────────┘
                    └──────────┘
```

## Cryptographic Primitives

### Hash Function: Poseidon

All circuits use the Poseidon hash function exclusively. Poseidon is an arithmetization-friendly hash designed for efficient representation inside arithmetic circuits over prime fields. It operates natively over the BN254 scalar field (≈254-bit prime), avoiding the bit-decomposition overhead required by hash functions like SHA-256 or Keccak.

Poseidon is used for:
- Key derivation (`publicKey = Poseidon(privateKey)`)
- UTXO commitments (`Poseidon(amount, pubkey, blinding, mint)`)
- Nullifier generation (`Poseidon(commitment, leafIndex, signature)`)
- Merkle tree hashing (binary Poseidon at each level)
- Viewing key derivation (`Poseidon(masterKey, scope)`)

### Proving System: Groth16

Groth16 produces constant-size proofs (3 group elements, ~192 bytes) with constant-time verification. The tradeoff is a circuit-specific trusted setup ceremony. Each circuit requires:

1. **Powers of Tau** — universal phase, reusable across circuits
2. **Phase 2** — circuit-specific contributions adding entropy

For production deployments, phase 2 must be a multi-party ceremony where security holds as long as at least one participant is honest.

### Elliptic Curve: BN254

The protocol operates over the BN254 (alt_bn128) curve, which provides:
- ~100-bit security level
- Efficient pairing operations for Groth16 verification
- Native support in Solana via the BN254 precompile syscalls

## UTXO Model

The core transaction circuit implements a 2-in/2-out UTXO model:

```
  Input UTXO₀ ──┐              ┌── Output UTXO₀
                 ├── Circuit ──┤
  Input UTXO₁ ──┘              └── Output UTXO₁
                      ↕
               publicAmount
         (net deposit or withdrawal)
```

Each UTXO is a **commitment** — a Poseidon hash binding together the amount, owner, blinding factor, and token mint. Spending a UTXO reveals its **nullifier** (a deterministic but unlinkable derivative) without revealing which commitment is being consumed.

### Commitment Scheme

```
commitment = Poseidon(amount, pubkey, blinding, mintAddress)
```

- `amount` — token quantity (248-bit range-checked)
- `pubkey` — owner's public key, derived as `Poseidon(privateKey)`
- `blinding` — random scalar for hiding (semantic security)
- `mintAddress` — SPL token mint address (or system program for SOL)

The blinding factor ensures that identical (amount, owner, mint) tuples produce distinct commitments.

### Nullifier Scheme

```
signature  = Poseidon(privateKey, commitment, leafIndex)
nullifier  = Poseidon(commitment, leafIndex, signature)
```

Nullifiers are deterministic — the same UTXO always produces the same nullifier — enabling double-spend detection. However, without the private key, an observer cannot link a nullifier to its source commitment.

The `signature` component binds the private key to the specific UTXO being spent, preventing nullifier forgery.

### Balance Conservation

The circuit enforces:

```
Σ(inputAmounts) + publicAmount = Σ(outputAmounts)
```

- **Deposit (Cloak):** `publicAmount > 0` — public tokens enter the pool
- **Withdrawal (Reveal):** `publicAmount < 0` — private UTXOs exit the pool
- **Transfer:** `publicAmount = 0` — value moves between private UTXOs

## Merkle Tree

Commitments are stored in an append-only Merkle tree of depth 26 (~67M leaves). The circuit verifies membership of input UTXOs against the on-chain root using Poseidon-based hashing at each level.

Zero-amount UTXOs (padding inputs) skip the root check, allowing transactions with fewer than 2 real inputs.

## Key Hierarchy

```
spendingPrivateKey
  │
  ├── publicKey = Poseidon(spendingPrivateKey)
  │     └── Used as UTXO owner identity
  │
  └── masterViewingKey = Poseidon(spendingPrivateKey, DOMAIN)
        │
        ├── scopedKey(0) = Poseidon(master, 0)  →  Proxy scope
        ├── scopedKey(1) = Poseidon(master, 1)  →  Pool scope
        └── scopedKey(2) = Poseidon(master, 2)  →  Full scope
```

A single spending key derives both the UTXO ownership identity and a hierarchy of viewing keys. Viewing keys enable selective disclosure to auditors — they can decrypt transaction data within their scope but cannot construct valid spending proofs.

The domain separator (`0x766965775f6b6579` = `"view_key"`) ensures the viewing key namespace is cryptographically isolated from spending operations.

## External Data Binding

Each transaction binds an `extDataHash` — a hash of auxiliary data (recipient address, relayer fee, encrypted outputs, etc.) that lives outside the proof. The circuit constrains `extDataHash` via a quadratic relation (`extDataHash² === extDataSquare`), ensuring the proof is bound to specific external parameters and cannot be replayed with different metadata.

## Constraint Counts

| Circuit | Approximate Constraints | Public Inputs |
|---------|------------------------|---------------|
| `stealth_tx` | ~30,000 | 7 |
| `inbox_registration` | ~250 | 2 |
| `viewing_key` | ~500 | 3 |

Constraint counts scale primarily with Poseidon rounds and Merkle tree depth. The stealth transaction circuit dominates due to two full Merkle proof verifications (26 levels each).
