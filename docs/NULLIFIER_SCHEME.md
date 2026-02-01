# Nullifier Scheme

Nullifiers are the mechanism that prevents double-spending in the UTXO model without revealing which commitment is being consumed.

## Construction

For each input UTXO, the circuit computes:

```
signature  = Poseidon(privateKey, commitment, leafIndex)
nullifier  = Poseidon(commitment, leafIndex, signature)
```

Where:
- `commitment = Poseidon(amount, pubkey, blinding, mintAddress)` — the UTXO being spent
- `leafIndex` — the position of the commitment in the Merkle tree (encoded as `pathIndices`)
- `privateKey` — the owner's secret spending key

## Properties

### Determinism

Given a fixed UTXO (commitment + leaf index) and its owner's private key, the nullifier is unique and reproducible. This is essential: the on-chain contract maintains a set of revealed nullifiers and rejects any transaction that attempts to reveal an already-seen nullifier.

### Unlinkability

An observer sees `nullifier` as a public input to the proof. Without `privateKey`, they cannot:

1. Recover `commitment` from `nullifier` (Poseidon preimage resistance)
2. Link the nullifier to any specific leaf in the Merkle tree
3. Determine whether two transactions were performed by the same user

The inclusion of `signature` (which depends on `privateKey`) in the nullifier hash ensures that even an adversary who knows `commitment` and `leafIndex` cannot predict the nullifier.

### Unforgeability

An adversary who does not know `privateKey` cannot produce a valid `(nullifier, proof)` pair for a given UTXO. The circuit enforces:

1. The `signature` is correctly derived from `privateKey`, `commitment`, and `leafIndex`
2. The `privateKey` derives the correct `publicKey` (matching the one in the commitment)
3. The `commitment` exists in the Merkle tree at the claimed position

All three checks must pass simultaneously, and the private key is the only witness that satisfies all constraints.

## Duplicate Nullifier Prevention

The circuit includes an explicit check that input nullifiers are pairwise distinct:

```circom
for (var i = 0; i < nIns - 1; i++) {
    for (var j = i + 1; j < nIns; j++) {
        sameNullifiers[index] = IsEqual();
        sameNullifiers[index].in[0] <== inputNullifier[i];
        sameNullifiers[index].in[1] <== inputNullifier[j];
        sameNullifiers[index].out === 0;
    }
}
```

This prevents a single transaction from spending the same UTXO twice within the same proof. Cross-transaction double-spend prevention is handled on-chain by the nullifier set.

## Security Considerations

**Why not just `Poseidon(privateKey, commitment)`?**

Including `leafIndex` binds the nullifier to a specific tree position. Without it, if the same commitment appeared at two different positions (e.g., due to duplicate deposits), both entries would produce the same nullifier, and only one could ever be spent.

**Why the two-layer construction?**

The `signature` intermediate value serves as a proof-of-knowledge gadget — it demonstrates the prover knows `privateKey` for this specific UTXO. The outer hash then mixes this authorization proof with the UTXO identity to produce the final nullifier. This separation makes the security argument cleaner: authorization and identifier generation are composed rather than entangled.
