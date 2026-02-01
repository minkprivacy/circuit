# Cryptographic Rationale

This document explains the design decisions behind the circuit system and the security properties they provide.

## Why Poseidon?

Traditional hash functions (SHA-256, Keccak-256) operate over bits, requiring expensive bit-decomposition gadgets inside arithmetic circuits. A single SHA-256 evaluation costs ~25,000 R1CS constraints, compared to ~250 for Poseidon.

The Mink circuits invoke Poseidon at every layer: key derivation, commitment construction, nullifier generation, Merkle hashing, and viewing key derivation. Using a non-algebraic hash would increase the stealth transaction circuit by an order of magnitude, making client-side proving impractical.

Poseidon's security relies on the algebraic hardness of the underlying permutation over the BN254 scalar field. The specific instantiation used (via `circomlib`) follows the parameterization from [Grassi et al., 2021](https://eprint.iacr.org/2019/458), with security margin for the number of rounds.

## Why Groth16?

| Property | Groth16 | PLONK | STARKs |
|----------|---------|-------|--------|
| Proof size | ~192 B | ~600 B | ~50 KB |
| Verification time | Constant (3 pairings) | Constant | O(log²n) |
| Trusted setup | Circuit-specific | Universal | None |
| Prover time | Fast | Moderate | Moderate |

Groth16 offers the smallest proofs and fastest verification, which directly translates to lower on-chain costs. The tradeoff — a circuit-specific trusted setup — is acceptable when mitigated by a properly conducted multi-party ceremony.

For Solana specifically, Groth16 over BN254 is the natural choice because the runtime provides native syscalls for BN254 pairing checks.

## Commitment Scheme Analysis

The UTXO commitment `Poseidon(amount, pubkey, blinding, mintAddress)` provides:

**Hiding (confidentiality):** Given a commitment `C`, an adversary cannot determine the underlying `(amount, pubkey, blinding, mint)` tuple. The random blinding factor ensures computational hiding — even if the adversary knows (or guesses) the amount, owner, and mint, each commitment looks uniformly random without knowledge of the blinding.

**Binding (integrity):** It is computationally infeasible to find two distinct UTXO tuples that hash to the same commitment. This follows from the collision resistance of Poseidon.

**Unlinkability:** Two commitments owned by the same user with the same amount appear unrelated to observers, since different blinding factors produce independent hash outputs.

## Nullifier Security

The nullifier scheme requires three properties:

1. **Determinism** — The same UTXO always produces the same nullifier, enabling double-spend detection via a simple on-chain set membership check.

2. **Unlinkability** — Given a nullifier `N`, an observer cannot determine which commitment `C` was consumed. The nullifier includes a signature component derived from the private key, so without the key, the preimage is unknown.

3. **Unforgeability** — An adversary cannot produce a valid nullifier for a UTXO they don't own. The signature `Poseidon(privateKey, commitment, leafIndex)` binds the private key into the nullifier computation.

The two-layer construction (signature, then nullifier hash) separates concerns: the signature proves authorization, while the outer hash ensures the nullifier reveals no information about its components.

## Range Checks

Output amounts are constrained to 248 bits via `Num2Bits(248)`. This prevents:

- **Field overflow attacks** — The BN254 scalar field is ~254 bits. Without range checks, an attacker could use field arithmetic wrapping to create value from nothing (e.g., spending 0 and producing an amount equal to the field modulus).

- **Negative amount encoding** — In a prime field, there are no negative numbers, but large field elements can encode effectively negative values when the conservation equation is checked modularly. The 248-bit bound ensures amounts stay well within the "positive" range.

The 6-bit margin (254 - 248) provides safety against edge cases in modular arithmetic.

## Merkle Tree Design

**Depth 26** supports 2²⁶ = 67,108,864 leaves. This balances:

- **Capacity** — sufficient for years of transaction volume
- **Proof size** — 26 path elements per Merkle proof
- **Circuit cost** — 26 Poseidon hashes per proof verification

The tree is append-only; leaves are never removed. This simplifies the on-chain data structure and avoids the complexity of sparse Merkle trees.

**Zero-amount padding:** Input UTXOs with `amount = 0` skip the root verification check (`ForceEqualIfEnabled` disabled). This allows transactions with fewer than 2 real inputs without requiring dummy entries in the Merkle tree.

## Viewing Key Isolation

The viewing key hierarchy uses domain separation to ensure cryptographic isolation:

```
masterViewingKey = Poseidon(spendingKey, 0x766965775f6b6579)
```

The domain constant (`"view_key"` encoded as hex) acts as a separator in the Poseidon input space. This guarantees that:

1. A viewing key cannot be used to derive the spending key (Poseidon preimage resistance)
2. A viewing key from one scope cannot be used to derive keys for other scopes
3. The viewing key derivation path is independent of the public key derivation path

The scoped hierarchy (Proxy / Pool / Full) enables minimal-privilege disclosure — an auditor examining inbox registrations only needs the Proxy-scoped key, without gaining visibility into pool transactions.

## External Data Binding

The `extDataHash` is bound to the proof via a quadratic constraint:

```
extDataSquare <== extDataHash * extDataHash
```

This ensures the proof includes `extDataHash` as a witness-dependent constraint. If an attacker attempts to resubmit the proof with different external data (e.g., redirecting a withdrawal to their own address), the verification will fail because the on-chain verifier checks the public input against the actual external data hash.

The quadratic form (rather than a simple equality) is a standard Circom pattern for binding public inputs without introducing additional hash computations.

## Anti-Replay in Inbox Registration

The `messageHash` public input in the inbox registration circuit binds each proof to a specific registration request. This prevents:

- **Proof replay** — resubmitting a valid proof for a different registration
- **Front-running** — observing a pending registration transaction and submitting a competing one with the same proof

The message hash typically encodes the token mint, a timestamp or nonce, and other request-specific parameters.

## Known Limitations

1. **Single-party setup** — The current build scripts use a single entropy contribution. Production deployments must conduct a multi-party ceremony.

2. **BN254 security level** — BN254 provides approximately 100 bits of security. While sufficient for current applications, the cryptographic community is gradually moving toward curves with higher security margins (e.g., BLS12-381 at ~128 bits). Solana's native support for BN254 makes this the pragmatic choice.

3. **Fixed UTXO shape** — The 2-in/2-out model requires padding for simpler transactions (e.g., a deposit uses 0-amount dummy inputs). This is a standard tradeoff in UTXO privacy protocols — it simplifies the circuit at the cost of slight inefficiency.

4. **Poseidon parameter assumptions** — Security depends on the specific Poseidon round parameters from circomlib being conservative for the BN254 field. The parameters follow published recommendations with additional safety margins.
