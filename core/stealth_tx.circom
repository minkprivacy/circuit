pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";
include "../lib/merkle.circom";
include "../lib/keypair.circom";

/// StealthTransaction - Privacy-preserving UTXO transaction circuit
/// Supports deposits (cloak) and withdrawals (reveal) of SOL/SPL tokens
///
/// UTXO structure:
/// - amount: Token amount
/// - pubkey: Owner's public key (derived from private key)
/// - blinding: Random value for hiding
/// - mintAddress: Token mint (system program for SOL)
///
/// commitment = Poseidon(amount, pubkey, blinding, mintAddress)
/// nullifier = Poseidon(commitment, leafIndex, signature)
///
/// @param levels - Merkle tree depth (26 = ~67M transactions)
/// @param nIns - Number of input UTXOs (2)
/// @param nOuts - Number of output UTXOs (2)
template StealthTransaction(levels, nIns, nOuts) {
    // Public inputs
    signal input root;
    signal input publicAmount;
    signal input extDataHash;
    signal input inputNullifier[nIns];
    signal input outputCommitment[nOuts];

    // Private inputs - mint
    signal input mintAddress;

    // Private inputs - input UTXOs
    signal input inAmount[nIns];
    signal input inPrivateKey[nIns];
    signal input inBlinding[nIns];
    signal input inPathIndices[nIns];
    signal input inPathElements[nIns][levels];

    // Private inputs - output UTXOs
    signal input outAmount[nOuts];
    signal input outPubkey[nOuts];
    signal input outBlinding[nOuts];

    // Components for input verification
    component inKeypair[nIns];
    component inSignature[nIns];
    component inCommitmentHasher[nIns];
    component inNullifierHasher[nIns];
    component inTree[nIns];
    component inCheckRoot[nIns];
    component inAmountCheck[nIns];
    var sumIns = 0;

    // Verify input UTXOs
    for (var tx = 0; tx < nIns; tx++) {
        // Range check: input amount must fit in 248 bits (prevents field overflow attacks)
        inAmountCheck[tx] = Num2Bits(248);
        inAmountCheck[tx].in <== inAmount[tx];

        // Derive public key from private key
        inKeypair[tx] = Keypair();
        inKeypair[tx].privateKey <== inPrivateKey[tx];

        // Compute commitment: H(amount, pubkey, blinding, mint)
        inCommitmentHasher[tx] = Poseidon(4);
        inCommitmentHasher[tx].inputs[0] <== inAmount[tx];
        inCommitmentHasher[tx].inputs[1] <== inKeypair[tx].publicKey;
        inCommitmentHasher[tx].inputs[2] <== inBlinding[tx];
        inCommitmentHasher[tx].inputs[3] <== mintAddress;

        // Compute signature for nullifier
        inSignature[tx] = Signature();
        inSignature[tx].privateKey <== inPrivateKey[tx];
        inSignature[tx].commitment <== inCommitmentHasher[tx].out;
        inSignature[tx].merklePath <== inPathIndices[tx];

        // Compute nullifier: H(commitment, pathIndex, signature)
        inNullifierHasher[tx] = Poseidon(3);
        inNullifierHasher[tx].inputs[0] <== inCommitmentHasher[tx].out;
        inNullifierHasher[tx].inputs[1] <== inPathIndices[tx];
        inNullifierHasher[tx].inputs[2] <== inSignature[tx].out;
        inNullifierHasher[tx].out === inputNullifier[tx];

        // Verify Merkle proof
        inTree[tx] = MerkleProof(levels);
        inTree[tx].leaf <== inCommitmentHasher[tx].out;
        inTree[tx].pathIndices <== inPathIndices[tx];
        for (var i = 0; i < levels; i++) {
            inTree[tx].pathElements[i] <== inPathElements[tx][i];
        }

        // Check root only for non-zero amounts (zero UTXOs are padding)
        inCheckRoot[tx] = ForceEqualIfEnabled();
        inCheckRoot[tx].in[0] <== root;
        inCheckRoot[tx].in[1] <== inTree[tx].root;
        inCheckRoot[tx].enabled <== inAmount[tx];

        sumIns += inAmount[tx];
    }

    // Components for output verification
    component outCommitmentHasher[nOuts];
    component outAmountCheck[nOuts];
    var sumOuts = 0;

    // Verify output UTXOs
    for (var tx = 0; tx < nOuts; tx++) {
        // Compute output commitment: H(amount, pubkey, blinding, mint)
        outCommitmentHasher[tx] = Poseidon(4);
        outCommitmentHasher[tx].inputs[0] <== outAmount[tx];
        outCommitmentHasher[tx].inputs[1] <== outPubkey[tx];
        outCommitmentHasher[tx].inputs[2] <== outBlinding[tx];
        outCommitmentHasher[tx].inputs[3] <== mintAddress;
        outCommitmentHasher[tx].out === outputCommitment[tx];

        // Range check: amount must fit in 248 bits
        outAmountCheck[tx] = Num2Bits(248);
        outAmountCheck[tx].in <== outAmount[tx];

        sumOuts += outAmount[tx];
    }

    // Prevent duplicate nullifiers
    component sameNullifiers[nIns * (nIns - 1) / 2];
    var index = 0;
    for (var i = 0; i < nIns - 1; i++) {
        for (var j = i + 1; j < nIns; j++) {
            sameNullifiers[index] = IsEqual();
            sameNullifiers[index].in[0] <== inputNullifier[i];
            sameNullifiers[index].in[1] <== inputNullifier[j];
            sameNullifiers[index].out === 0;
            index++;
        }
    }

    // Conservation: inputs + publicAmount == outputs
    sumIns + publicAmount === sumOuts;

    // Bind extDataHash to prevent tampering
    signal extDataSquare <== extDataHash * extDataHash;
}

// Entry point: 2-input, 2-output transaction with 26-level tree
component main {public [root, publicAmount, extDataHash, inputNullifier, outputCommitment]} = StealthTransaction(26, 2, 2);
