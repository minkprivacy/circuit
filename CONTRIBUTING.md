# Contributing

Contributions to the Mink circuit library are welcome. This document outlines the process and conventions.

## Development Setup

```bash
# Prerequisites
# - Circom 2: https://docs.circom.io/getting-started/installation/
# - Node.js >= 18
# - pnpm

# Install dependencies
pnpm install

# Download Powers of Tau ceremony file
pnpm download:ptau

# Build all circuits
pnpm build:all
```

## Project Conventions

### Circuit Style

- Use `pragma circom 2.0.0`
- Document templates with `///` comments describing inputs, outputs, and purpose
- Prefix private signals with `in` or `out` to indicate direction
- Use descriptive signal names (`inAmount`, `outPubkey`) over abbreviations
- Keep templates focused — one cryptographic operation per template

### File Organization

- **`core/`** — Circuit entry points (files with `component main`)
- **`lib/`** — Reusable templates without `component main`
- **`scripts/`** — Build and conversion tooling
- **`docs/`** — Technical documentation

### Commit Messages

Use conventional commits:

```
feat(circuits): add range check to viewing key scope
fix(lib): correct Merkle path index encoding
docs: add nullifier scheme documentation
```

## Adding a New Circuit

1. Create the template in `lib/` (if reusable) or `core/` (if standalone)
2. Add build scripts to `package.json` following the existing pattern
3. Add the circuit to `scripts/convert_vkey.cjs` if it requires on-chain verification
4. Document the circuit's purpose, public/private inputs, and security properties
5. Update `docs/ARCHITECTURE.md` with the new circuit in the dependency graph

## Security Considerations

When modifying circuits:

- **Never remove range checks** without documenting the rationale
- **Verify conservation equations** still hold after changes
- **Check nullifier determinism** — the same UTXO must always produce the same nullifier
- **Test with edge cases**: zero amounts, maximum field elements, duplicate inputs
- **Review Poseidon arity** — ensure the number of inputs matches the hash instantiation

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly via a GitHub security advisory rather than a public issue. See [SECURITY.md](./SECURITY.md) for details.
