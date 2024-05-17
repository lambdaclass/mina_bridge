//! A simple script to generate and verify the proof of a given program.

use kimchi_verifier_ffi::generate_test_proof;
use sp1_sdk::{ProverClient, SP1Stdin};

const ELF: &[u8] = include_bytes!("../../program/elf/riscv32im-succinct-zkvm-elf");

unsafe fn as_bytes<T: Sized>(data: &T) -> &[u8] {
    std::slice::from_raw_parts((data as *const T) as *const u8, std::mem::size_of_val(data))
}

fn main() {
    // Setup the logger.
    sp1_sdk::utils::setup_logger();

    // Generate proof.
    let mut stdin = SP1Stdin::new();
    let (proof, index, srs) = generate_test_proof();

    stdin.write(&proof);
    stdin.write(&index);

    unsafe {
        let srs_bytes = as_bytes(&srs);
        stdin.write_slice(srs_bytes);
    }

    let client = ProverClient::new();
    let (pk, vk) = client.setup(ELF);
    let mut proof = client.prove_groth16(&pk, stdin).expect("proving failed");

    // Read output.
    let result = proof.public_values.read::<bool>();
    println!("Verification result: {}", result);

    // Save proof.
    proof
        .save("proof-with-io.json")
        .expect("saving proof failed");

    // Verify proof.
    client
        .verify_groth16(&proof, &vk)
        .expect("verification failed");

    println!("successfully generated and verified proof for the program!")
}
