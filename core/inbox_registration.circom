pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "../lib/keypair.circom";

/// InboxRegistration - Proves ownership of a ZK identity for inbox registration
///
/// This circuit proves that the user knows the private key corresponding to
/// a public key (zkPubkey) without revealing the private key.
///
/// Use case: When registering a Private Inbox, the user proves they own the
/// ZK identity (zkPubkey) that will receive funds. This prevents front-running
/// and ensures only the legitimate owner can claim incoming deposits.
///
/// @param privateKey - User's secret spending key (PRIVATE)
/// @param zkPubkey - User's public identity = Poseidon(privateKey) (PUBLIC)
/// @param messageHash - Hash of registration message for anti-replay (PUBLIC)
template InboxRegistration() {
    // Public inputs
    signal input zkPubkey;       // Public ZK identity
    signal input messageHash;    // Anti-replay nonce (hash of mint + timestamp + nonce)

    // Private inputs
    signal input privateKey;     // Secret spending key

    // Derive public key from private key
    component keypair = Keypair();
    keypair.privateKey <== privateKey;

    // Constraint: zkPubkey must equal derived public key
    // This proves knowledge of the private key without revealing it
    keypair.publicKey === zkPubkey;

    // Bind messageHash to prevent proof replay
    // This ensures each proof is unique to a specific registration request
    signal messageSquare <== messageHash * messageHash;
}

component main {public [zkPubkey, messageHash]} = InboxRegistration();
