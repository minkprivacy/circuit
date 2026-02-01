pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";

/// Derives a public key from a private key using Poseidon hash
/// @input privateKey - The secret key
/// @output publicKey - Derived public key
template Keypair() {
    signal input privateKey;
    signal output publicKey;

    component hasher = Poseidon(1);
    hasher.inputs[0] <== privateKey;
    publicKey <== hasher.out;
}

/// Creates a signature for nullifier derivation
/// @input privateKey - The secret key
/// @input commitment - The UTXO commitment being spent
/// @input merklePath - The leaf index in the tree
/// @output out - Signature hash
template Signature() {
    signal input privateKey;
    signal input commitment;
    signal input merklePath;
    signal output out;

    component hasher = Poseidon(3);
    hasher.inputs[0] <== privateKey;
    hasher.inputs[1] <== commitment;
    hasher.inputs[2] <== merklePath;
    out <== hasher.out;
}
