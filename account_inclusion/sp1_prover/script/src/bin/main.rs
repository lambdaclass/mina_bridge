use core::{smart_contract_utility::get_tip_state_hash, utils::env::EnvironmentVariables};

use account_inclusion_verifier::{query_leaf_and_merkle_path, query_merkle_root};
use fibonacci_lib::PublicValuesStruct;
use o1_utils::FieldHelpers;
use sp1_sdk::{ProverClient, SP1Stdin};

/// The ELF (executable and linkable format) file for the Succinct RISC-V zkVM.
pub const VERIFICATION_ELF: &[u8] = include_bytes!("../../../elf/riscv32im-succinct-zkvm-elf");

#[tokio::main]
async fn main() {
    // Setup the logger.
    sp1_sdk::utils::setup_logger();

    let EnvironmentVariables {
        rpc_url,
        chain,
        eth_rpc_url,
        ..
    } = EnvironmentVariables::new().unwrap();

    let args: Vec<String> = std::env::args().collect();
    let public_key = args.get(1).unwrap();

    let state_hash = get_tip_state_hash(&chain, &eth_rpc_url).await.unwrap();

    let (leaf_hash, merkle_path) = query_leaf_and_merkle_path(&rpc_url, public_key).unwrap();

    let merkle_root = query_merkle_root(&rpc_url, state_hash).unwrap();

    // Setup the prover client.
    let client = ProverClient::new();

    // Setup the inputs.
    let mut stdin = SP1Stdin::new();

    stdin.write_vec(leaf_hash.to_bytes());
    stdin.write_vec(merkle_root.to_bytes());
    for merkle_node in merkle_path.into_iter() {
        stdin.write_vec(merkle_node.to_bytes());
    }

    // Setup the program for proving.
    let (pk, vk) = client.setup(VERIFICATION_ELF);

    // Generate the proof
    let proof = client
        .prove(&pk, stdin)
        .run()
        .expect("failed to generate proof");

    println!("Successfully generated proof!");

    // Verify the proof.
    client.verify(&proof, &vk).expect("failed to verify proof");
    println!("Successfully verified proof!");
}
