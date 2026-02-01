# Security Policy

## Scope

This policy covers the Circom circuit definitions, library templates, and build scripts in this repository. It does not cover the on-chain verifier program or client SDK, which have separate security processes.

## Reporting a Vulnerability

If you discover a security vulnerability in the circuits, **do not open a public issue**. Instead:

1. Go to the repository's **Security** tab on GitHub
2. Click **Report a vulnerability**
3. Provide a detailed description including:
   - Which circuit(s) are affected
   - The attack vector and its impact
   - Steps to reproduce (if applicable)
   - Suggested fix (if you have one)

We aim to acknowledge reports within 48 hours and provide an initial assessment within 7 days.

## What Qualifies

- Constraint under-specification (missing constraints that allow invalid witnesses)
- Soundness issues (ability to generate valid proofs for false statements)
- Information leakage through public signals
- Nullifier collision or predictability attacks
- Conservation equation bypasses
- Trusted setup ceremony weaknesses

## Current Status

These circuits are under active development and have **not** been formally audited. The trusted setup uses a single-party ceremony (development only). Do not rely on these circuits for securing real value until:

1. A formal audit has been completed
2. A multi-party trusted setup ceremony has been conducted
3. The results have been independently verified

## Acknowledgments

We will credit researchers who responsibly disclose vulnerabilities (unless they prefer to remain anonymous).
