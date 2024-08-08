//! A simple program that takes a number `n` as input, and writes the `n-1`th and `n`th fibonacci
//! number as an output.

// These two lines are necessary for the program to properly compile.
//
// Under the hood, we wrap your main function with some extra code so that it behaves properly
// inside the zkVM.
#![no_main]
sp1_zkvm::entrypoint!(main);

use account_inclusion_verifier::verify_merkle_proof;

pub fn main() {
    // let leaf_hash = Fp::from_bytes(sp1_zkvm::io::read());
    // let merkle_path = todo! custom serialization of bytes
    // let merkle_root = Fp::from_bytes(sp1_zkvm::io::read());
    //
    // sp1_zkvm::io::commit(&leaf_hash);
    // sp1_zkvm::io::commit(&merkle_path);
    // sp1_zkvm::io::commit(&merkle_root);
    //
    // let result = verify_merkle_proof(leaf_hash, merkle_path, merkle_root);
    //
    // sp1_zkvm::io::commit(&result);
}
