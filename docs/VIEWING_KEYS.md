# Viewing Keys

Viewing keys enable selective disclosure of transaction data to third parties without granting spending authority. This mechanism supports regulatory compliance, voluntary audits, and delegated monitoring.

## Motivation

A privacy protocol that provides no path to auditability faces adoption barriers in regulated environments. Viewing keys solve this by allowing users to derive purpose-limited keys from their spending key, each granting read access to a specific scope of activity.

The key insight: **audit capability and spending capability must be cryptographically independent**. A viewing key holder can observe transactions but cannot construct valid proofs to spend funds.

## Derivation

The derivation follows a two-level hierarchy:

```
spendingPrivateKey
    │
    │  Poseidon(spendingKey, DOMAIN)
    ▼
masterViewingKey
    │
    ├── Poseidon(master, 0)  →  Proxy-scoped key
    ├── Poseidon(master, 1)  →  Pool-scoped key
    └── Poseidon(master, 2)  →  Full-scoped key
```

**Domain separator:** `DOMAIN = 0x766965775f6b6579` (ASCII encoding of `"view_key"`)

The domain separator ensures the viewing key derivation path is cryptographically isolated from the public key derivation path (`publicKey = Poseidon(spendingKey)`). Without it, a relationship between the two derivation paths could leak information.

## Scopes

| Scope | Value | Visibility |
|-------|-------|------------|
| Proxy | 0 | Inbox registrations and incoming deposits |
| Pool | 1 | Privacy pool transactions (transfers, withdrawals) |
| Full | 2 | All activity across both Proxy and Pool |

Scoped keys enforce the principle of least privilege. An auditor examining deposit compliance receives only the Proxy key; they gain no visibility into how funds move within the privacy pool.

## Circuits

### ViewingKeyDerivation

The primary circuit used during on-chain registration. It proves:

1. The prover owns the spending key corresponding to `zkPubkey`
2. The `viewingKeyHash` was correctly derived through the domain-separated hierarchy
3. The derivation used the claimed `scope`

The viewing key itself is not revealed as a public input — only its hash. This allows the on-chain contract to verify the derivation without exposing the key material. The actual key is shared off-chain through an encrypted channel.

**Public inputs:** `zkPubkey`, `viewingKeyHash`, `scope`
**Private inputs:** `spendingPrivateKey`

### ViewingKeyProof

A secondary circuit for off-chain use when sharing a viewing key with a third party. Unlike `ViewingKeyDerivation`, this circuit reveals the actual viewing key as a public input, allowing the recipient to verify it was correctly derived.

**Public inputs:** `zkPubkey`, `viewingKey`, `scope`
**Private inputs:** `spendingPrivateKey`

## Security Properties

**Forward secrecy (limited):** Viewing keys are deterministically derived. If the spending key is compromised, all viewing keys are also compromised. However, viewing key compromise does not endanger the spending key (Poseidon preimage resistance).

**Scope isolation:** A key for scope `i` cannot be used to derive the key for scope `j ≠ i`. Each scoped key is an independent Poseidon output — knowing `Poseidon(master, 0)` reveals nothing about `Poseidon(master, 1)`.

**Non-transferability of authority:** A viewing key proves derivation from a specific `zkPubkey`. An auditor cannot use a viewing key received for identity A to observe identity B, even if both are owned by the same user (assuming different spending keys).

## Typical Usage Flow

1. User generates a spending key and derives their `zkPubkey`
2. User registers their inbox on-chain, providing a proof from `ViewingKeyDerivation`
3. When audit is required, user derives the appropriate scoped viewing key
4. User generates a `ViewingKeyProof` and shares the key + proof with the auditor
5. Auditor verifies the proof, confirming the key legitimately derives from the claimed identity
6. Auditor uses the viewing key to decrypt relevant transaction data off-chain
