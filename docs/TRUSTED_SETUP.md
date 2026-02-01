# Trusted Setup

Groth16 requires a structured reference string (SRS) generated through a two-phase ceremony. This document describes the setup process, its security implications, and production requirements.

## Background

The SRS contains group elements that encode a secret value τ (tau). If any party learns τ, they can forge proofs for arbitrary statements — effectively creating valid-looking proofs for invalid transactions. The ceremony's purpose is to generate the SRS while ensuring τ is destroyed.

## Two-Phase Ceremony

### Phase 1: Powers of Tau

A universal ceremony producing powers of τ in the group: `{τ⁰, τ¹, τ², ..., τⁿ}`. This phase is circuit-independent and can be reused across all circuits.

The Mink circuits use the Hermez network's `powersOfTau28_hez_final_17` ceremony file, which supports circuits up to 2¹⁷ = 131,072 constraints. This ceremony involved 54 independent contributions.

```bash
pnpm download:ptau
# Downloads pot17_final.ptau (~300 MB)
```

### Phase 2: Circuit-Specific Setup

Each circuit requires its own Phase 2 ceremony that specializes the universal SRS for the specific constraint system. The current build scripts perform a single-party contribution:

```bash
# For each circuit:
npx snarkjs groth16 setup <circuit>.r1cs pot17_final.ptau <circuit>_0000.zkey
npx snarkjs zkey contribute <circuit>_0000.zkey <circuit>_final.zkey --name='mink'
npx snarkjs zkey export verificationkey <circuit>_final.zkey <circuit>_vkey.json
```

## Security Model

The ceremony is secure under the **1-of-N honest participant** assumption: if at least one contributor generates their randomness honestly and destroys it afterward, the resulting SRS is secure.

A single-party ceremony (as in the current development setup) provides **no** security guarantee — the single contributor knows τ and could forge proofs.

## Production Ceremony Requirements

For a production deployment, Phase 2 must be conducted as a multi-party computation:

1. **Multiple independent contributors** — each adds their own randomness
2. **Public verifiability** — each contribution can be independently verified
3. **Diverse infrastructure** — contributors should use different hardware, software, and networks
4. **Attestation** — each contributor publishes a signed statement describing their setup

snarkjs supports multi-party ceremonies natively:

```bash
# Contributor 1
npx snarkjs zkey contribute circuit_0000.zkey circuit_0001.zkey --name='contributor1'

# Contributor 2
npx snarkjs zkey contribute circuit_0001.zkey circuit_0002.zkey --name='contributor2'

# ... continue for N contributors

# Apply random beacon (optional final step)
npx snarkjs zkey beacon circuit_000N.zkey circuit_final.zkey <beacon_hash> 10

# Verify the full ceremony chain
npx snarkjs zkey verify circuit.r1cs pot17_final.ptau circuit_final.zkey
```

## Verification Key Export

After the ceremony, verification keys are exported in two formats:

1. **JSON** — for off-chain verification and SDK integration
2. **Rust constants** — for on-chain Solana program verification

The `convert_vkey.cjs` script transforms the JSON verification key into Rust source with `hex_literal` macro constants, suitable for the Solana BN254 pairing verifier:

```bash
node scripts/convert_vkey.cjs --all
```

This generates Rust modules with the elliptic curve points (α, β, γ, δ, IC) as compile-time byte arrays.

## Artifacts

The build process generates the following artifacts (all gitignored):

| File | Description |
|------|-------------|
| `<circuit>.r1cs` | Constraint system (R1CS format) |
| `<circuit>.wasm` | WebAssembly witness calculator |
| `<circuit>.sym` | Symbol file for debugging |
| `<circuit>_0000.zkey` | Initial zkey (after Phase 1) |
| `<circuit>_final.zkey` | Final zkey (after Phase 2 contributions) |
| `<circuit>_vkey.json` | Verification key (JSON) |
