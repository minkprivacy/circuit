pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "../lib/keypair.circom";

/// ViewingKeyDerivation - Derives viewing keys from spending key
///
/// Viewing keys allow third parties (auditors, compliance) to see transaction
/// details without being able to spend funds.
///
/// Derivation hierarchy:
/// 1. masterViewing = Poseidon(spendingPrivateKey, domain)
///    - domain separates viewing key namespace from spending
///
/// 2. scopedViewingKey = Poseidon(masterViewing, scope)
///    - scope: 0 = Proxy (inbox only), 1 = Pool (privacy pool only), 2 = Full (both)
///
/// Use cases:
/// - Auditor receives scopedViewingKey to audit specific scope
/// - User can prove viewingKey derives from their identity without revealing spending key
///
/// @param zkPubkey - User's public ZK identity (PUBLIC)
/// @param viewingKeyHash - Hash of the scoped viewing key (PUBLIC)
/// @param scope - Viewing key scope: 0=Proxy, 1=Pool, 2=Full (PUBLIC)
/// @param spendingPrivateKey - User's secret spending key (PRIVATE)
template ViewingKeyDerivation() {
    // Public inputs
    signal input zkPubkey;          // Public ZK identity
    signal input viewingKeyHash;    // Hash of scoped viewing key
    signal input scope;             // 0 = Proxy, 1 = Pool, 2 = Full

    // Private inputs
    signal input spendingPrivateKey; // Secret spending key

    // Domain separator for viewing key derivation
    // This ensures viewing keys cannot be confused with spending keys
    var VIEWING_KEY_DOMAIN = 0x766965775f6b6579; // "view_key" as hex

    // Step 1: Verify zkPubkey matches the spending key
    component keypair = Keypair();
    keypair.privateKey <== spendingPrivateKey;
    keypair.publicKey === zkPubkey;

    // Step 2: Derive master viewing key
    // masterViewing = Poseidon(spendingPrivateKey, domain)
    component masterDerivation = Poseidon(2);
    masterDerivation.inputs[0] <== spendingPrivateKey;
    masterDerivation.inputs[1] <== VIEWING_KEY_DOMAIN;

    // Step 3: Derive scoped viewing key
    // scopedViewingKey = Poseidon(masterViewing, scope)
    component scopeDerivation = Poseidon(2);
    scopeDerivation.inputs[0] <== masterDerivation.out;
    scopeDerivation.inputs[1] <== scope;

    // Step 4: Hash the viewing key for public comparison
    // This allows proving correct derivation without revealing the actual key
    component viewingKeyHasher = Poseidon(1);
    viewingKeyHasher.inputs[0] <== scopeDerivation.out;

    // Constraint: viewingKeyHash must match derived hash
    viewingKeyHasher.out === viewingKeyHash;
}

/// ViewingKeyProof - Proves a viewing key was correctly derived
/// This is used when sharing viewing keys with third parties
/// to prove they are legitimate without revealing the spending key
template ViewingKeyProof() {
    // Public inputs
    signal input zkPubkey;          // Public ZK identity
    signal input viewingKey;        // The actual viewing key being shared (PUBLIC for audit)
    signal input scope;             // Scope of the viewing key

    // Private inputs
    signal input spendingPrivateKey; // Secret spending key

    var VIEWING_KEY_DOMAIN = 0x766965775f6b6579;

    // Verify zkPubkey
    component keypair = Keypair();
    keypair.privateKey <== spendingPrivateKey;
    keypair.publicKey === zkPubkey;

    // Derive master viewing key
    component masterDerivation = Poseidon(2);
    masterDerivation.inputs[0] <== spendingPrivateKey;
    masterDerivation.inputs[1] <== VIEWING_KEY_DOMAIN;

    // Derive scoped viewing key
    component scopeDerivation = Poseidon(2);
    scopeDerivation.inputs[0] <== masterDerivation.out;
    scopeDerivation.inputs[1] <== scope;

    // Verify the provided viewing key matches the derivation
    scopeDerivation.out === viewingKey;
}

// Main component for on-chain registration verification
component main {public [zkPubkey, viewingKeyHash, scope]} = ViewingKeyDerivation();
