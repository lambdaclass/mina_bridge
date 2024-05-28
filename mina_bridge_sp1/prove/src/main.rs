//! A simple script to generate and verify the proof of a given program.

use std::fs::File;

use kimchi_verifier_ffi::generate_test_proof;
use sp1_prover::SP1CoreProof;
use sp1_sdk::{
    artifacts::try_install_groth16_artifacts, ProverClient, SP1CompressedProof,
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

    // Setup SP1 client
    let client = ProverClient::new();
    let (pk, vk) = client.setup(ELF);
    let prover = client.prover.sp1_prover();

    // Prove program execution
    let mut proof = prover
        .prove_core(&pk, &stdin)
        .expect("shard proving failed");

    // Read output.
    let result = proof.public_values.read::<bool>();
    println!("Verification result: {}", result);

    // Save proof with metadata
    proof
        .save("proof_with_metadata.bin")
        .expect("saving proof with metadata failed");

    /* Temporarily disable for faster iteration
    // Save proof with public values (this is the result of a normal JSON proof)
    // without compression or wrapping.
    let proof_with_public = SP1ProofWithPublicValues {
        proof: proof.proof.0.clone(),
        stdin: proof.stdin.clone(),
        public_values: proof.public_values.clone(),
    };
    proof_with_public
        .save("proof_with_public.json")
        .expect("saving proof with public failed");

    // Verify proof.
    client
        .verify(&proof_with_public, &vk)
        .expect("proof with public verification failed");
    */

    // Compress proof
    let deferred_proofs = stdin.proofs.iter().map(|p| p.0.clone()).collect();
    let public_values = proof.public_values.clone();
    let reduce_proof = prover
        .compress(&pk.vk, proof, deferred_proofs)
        .expect("compression failed");

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
    let compress_proof = prover.shrink(reduce_proof).expect("shrink failed");
    let outer_proof = prover
        .wrap_bn254(compress_proof)
        .expect("wrap bn254 failed");

    // Wrap SNARK-friendly bn254 proof over a Groth16.
    let groth16_aritfacts = try_install_groth16_artifacts();
    let proof = prover.wrap_groth16(outer_proof, &groth16_aritfacts);
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
