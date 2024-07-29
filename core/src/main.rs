extern crate dotenv;

use core::{aligned_polling_service, mina_polling_service, smart_contract_utility};
use dotenv::dotenv;
use ethers::abi::AbiEncode;
use log::{error, info};
use std::path::PathBuf;

#[tokio::main]
async fn main() -> Result<(), String> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    info!("Mina bridge starts");

    if let Err(err) = dotenv() {
        error!("Couldn't load .env file: {}", err);
    }

    let rpc_url = std::env::var("MINA_RPC_URL").expect("couldn't read MINA_RPC_URL env. variable.");
    let output_path = "."; // TODO(xqft): embellish this

    let mut proof_path_buf = PathBuf::from(output_path);
    proof_path_buf.push("protocol_state.proof");

    let mut public_input_path_buf = PathBuf::from(output_path);
    public_input_path_buf.push("protocol_state.pub");

    // TODO(xqft): add logging to mina_polling_service
    info!("Executing Mina polling service");
    let mina_proof = mina_polling_service::query_and_serialize(
        &rpc_url,
        proof_path_buf.to_str().unwrap(),
        public_input_path_buf.to_str().unwrap(),
    )
    .inspect_err(|err| error!("{}", err))?;

    info!("Executing Aligned polling service");
    let verification_data = aligned_polling_service::submit(&mina_proof)
        .await
        .inspect_err(|err| error!("{}", err))?;

    info!("Updating the bridge's smart contract");
    let pub_input = mina_proof
        .pub_input
        .ok_or("Missing public inputs from Mina proof")?;
    let new_state_hash = smart_contract_utility::update(verification_data, pub_input)
        .await
        .inspect_err(|err| error!("{}", err))?;

    info!(
        "Success! verified state hash {} was stored in the bridge's smart contract",
        new_state_hash.encode_hex()
    );
    Ok(())
}
