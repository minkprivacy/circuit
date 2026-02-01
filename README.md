# Mink Privacy Circuits

Zero-knowledge circuit library for privacy-preserving UTXO transactions on Solana, built with [Circom 2](https://docs.circom.io/) and [Groth16](https://eprint.iacr.org/2016/260).

The system implements a 2-in/2-out UTXO model with Poseidon-based commitments, nullifiers, and Merkle proofs. It supports private deposits, withdrawals, and transfers of SOL and SPL tokens, with optional selective disclosure through scoped viewing keys.

## Circuits

### StealthTransaction (`core/stealth_tx.circom`)

Privacy-preserving UTXO transaction circuit supporting three operations:

- **Cloak** — deposit public tokens into private UTXOs
- **Reveal** — withdraw private UTXOs back to public tokens
- **Transfer** — move value between private UTXOs

Each transaction consumes 2 input UTXOs and produces 2 output UTXOs, enforcing balance conservation: `Σ inputs + publicAmount = Σ outputs`.

**Parameters:** Merkle tree depth 26 (~67M leaves), 2 inputs, 2 outputs

**Public inputs:** `root`, `publicAmount`, `extDataHash`, `inputNullifier[2]`, `outputCommitment[2]`

**UTXO structure:**
```
commitment = Poseidon(amount, pubkey, blinding, mintAddress)
nullifier  = Poseidon(commitment, leafIndex, signature)
```

### InboxRegistration (`core/inbox_registration.circom`)

Proves ownership of a ZK identity (knowledge of the private key behind a public key) for inbox registration. Prevents front-running by binding the proof to a specific registration request via `messageHash`.

**Public inputs:** `zkPubkey`, `messageHash`

### ViewingKeyDerivation (`core/viewing_key.circom`)

Derives scoped viewing keys from a spending key through a domain-separated Poseidon hierarchy. Viewing keys enable selective disclosure to auditors without exposing spending authority.

**Derivation:**
```
masterViewing    = Poseidon(spendingKey, domain)
scopedViewingKey = Poseidon(masterViewing, scope)
```

**Scopes:** 0 = Proxy (inbox), 1 = Pool (privacy pool), 2 = Full

**Public inputs:** `zkPubkey`, `viewingKeyHash`, `scope`

## Libraries

| File | Description |
|------|-------------|
| `lib/keypair.circom` | Key derivation (`Keypair`) and nullifier signatures (`Signature`) via Poseidon |
| `lib/merkle.circom` | Merkle proof verification with Poseidon hashing |

## Prerequisites

- [Circom 2](https://docs.circom.io/getting-started/installation/)
- [Node.js](https://nodejs.org/) >= 18
- [pnpm](https://pnpm.io/)

## Getting Started

```bash
# Install dependencies
pnpm install

# Download Powers of Tau ceremony file (~300 MB)
pnpm download:ptau

# Build all circuits (compile + trusted setup + contribute + export vkey)
pnpm build:all
```

## Build Pipeline

Each circuit goes through four stages:

1. **Compile** — generates R1CS constraints, WASM witness calculator, and symbol file
2. **Setup** — Groth16 trusted setup using Powers of Tau
3. **Contribute** — adds entropy to the ceremony (see [Trusted Setup](docs/TRUSTED_SETUP.md))
4. **Export vkey** — extracts verification key for on-chain verification

```bash
# Build individual circuits
pnpm build:stealth
pnpm build:inbox
pnpm build:viewing

# Convert verification keys to Rust constants for on-chain verifier
pnpm convert-vkey:all
```

## Project Structure

```
circuits/
├── core/                           # Circuit entry points
│   ├── stealth_tx.circom           # UTXO transaction circuit
│   ├── inbox_registration.circom   # Identity proof for inbox
│   └── viewing_key.circom          # Viewing key derivation
├── lib/                            # Reusable templates
│   ├── keypair.circom              # Key derivation & signatures
│   └── merkle.circom               # Merkle proof verification
├── scripts/
│   └── convert_vkey.cjs            # Verification key → Rust constants
├── docs/                           # Technical documentation
│   ├── ARCHITECTURE.md             # System design and circuit topology
│   ├── CRYPTOGRAPHIC_RATIONALE.md  # Design decisions and security analysis
│   ├── NULLIFIER_SCHEME.md         # Nullifier construction and properties
│   ├── VIEWING_KEYS.md             # Viewing key hierarchy and usage
│   └── TRUSTED_SETUP.md           # Ceremony process and requirements
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE                         # MIT
├── package.json
└── README.md
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System overview, circuit dependencies, UTXO model, key hierarchy |
| [Cryptographic Rationale](docs/CRYPTOGRAPHIC_RATIONALE.md) | Design decisions, security properties, and known limitations |
| [Nullifier Scheme](docs/NULLIFIER_SCHEME.md) | Nullifier construction, determinism, unlinkability, unforgeability |
| [Viewing Keys](docs/VIEWING_KEYS.md) | Scoped viewing key derivation and selective disclosure |
| [Trusted Setup](docs/TRUSTED_SETUP.md) | Ceremony phases, production requirements, and artifact descriptions |

## Security

These circuits are under active development and have not been formally audited. See [SECURITY.md](SECURITY.md) for the vulnerability reporting process.

**Important:** The current build uses a single-party trusted setup suitable only for development. Production deployments require a multi-party ceremony. See [Trusted Setup](docs/TRUSTED_SETUP.md) for details.

## License

MIT
