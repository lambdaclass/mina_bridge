//! A simple script to generate and verify the proof of a given program.

use std::fs::File;

use kimchi_verifier_ffi::generate_test_proof;
use sp1_sdk::{
    artifacts::get_groth16_artifacts_dir, ProverClient, SP1CompressedProof, SP1CoreProof,
    SP1ProofWithPublicValues, SP1Stdin,
};

const ELF: &[u8] = include_bytes!("../../program/elf/riscv32im-succinct-zkvm-elf");

fn main() {
    // Setup the logger.
    sp1_sdk::utils::setup_logger();

    // Generate test Kimchi proof.
    let mut stdin = SP1Stdin::new();
    let (proof, index, srs) = generate_test_proof();

    // Write test Kimchi proof to stdin
    stdin.write(&proof);
    stdin.write(&index);
    stdin.write(&srs);
    stdin.write(&srs.lagrange_bases);

    // Setup SP1 client and prover
    let client = ProverClient::new();
    let (pk, vk) = client.setup(ELF);
    let prover = client.prover.sp1_prover();

    // Read saved proof
    println!("Reading shard proof...");
    let mut proof: SP1CoreProof = bincode::deserialize_from(
        File::open("proof_with_metadata.bin").expect("could not read proof_with_metadata.bin"),
    )
    .expect("could not deserialize proof");
    println!("Shard proof successfully deserialized!");

    /* Temporarily disable for faster iteration
        let proof_with_public = SP1ProofWithPublicValues {
            proof: proof.proof.0.clone(),
            stdin: proof.stdin.clone(),
            public_values: proof.public_values.clone(),
        };

        println!("Verifying shard proof...");
        // Verify proof.
        client
            .verify(&proof_with_public, &vk)
            .expect("proof with public verification failed");
        println!("Proof was verified!");
    */

    // Read output.
    let result = proof.public_values.read::<bool>();
    println!("Kimchi verification result: {}", result);

    println!("Compressing proof...");
    // Compress proof
    let deferred_proofs = stdin.proofs.iter().map(|p| p.0.clone()).collect();
    let public_values = proof.public_values.clone();
    let reduce_proof = prover.compress(&pk.vk, proof, deferred_proofs);

    // Save reduce proof
    bincode::serialize_into(
        File::create("reduce_proof.bin").expect("failed to open file"),
        &reduce_proof,
    )
    .expect("saving reduce proof failed");

    // Save reduced compressed proof (this is the result of a normal JSON
    // compressed proof)
    SP1CompressedProof {
        proof: reduce_proof.proof.clone(),
        stdin: stdin.clone(),
        public_values: public_values.clone(),
    }
    .save("reduce_compressed_proof.json")
    .expect("saving reduce compressed proof failed");

    // Compress and wrap proof over SNARK-friendly bn254
    let compress_proof = prover.shrink(reduce_proof);
    let outer_proof = prover.wrap_bn254(compress_proof);

    // Wrap SNARK-friendly bn254 proof over a Groth16.
    let artifacts_dir = get_groth16_artifacts_dir();
    let proof = prover.wrap_groth16(outer_proof, artifacts_dir);
    let groth16_proof = SP1ProofWithPublicValues {
        proof,
        stdin,
        public_values,
    };

    // Save groth16 proof
    groth16_proof
        .save("groth16_proof.json")
        .expect("saving groth16 proof failed");

    // Verify groth16 proof
    client
        .verify_groth16(&groth16_proof, &vk)
        .expect("groth 16 proof is not valid");

    println!("successfully generated and verified proof for the program!")
}
