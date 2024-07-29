extern crate dotenv;

use core::{aligned_polling_service, mina_polling_service, smart_contract_utility};
use dotenv::dotenv;
use ethers::abi::AbiEncode;
use log::{debug, error, info};
use std::process;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Loading .env");
    dotenv().unwrap_or_else(|err| {
        error!("Couldn't load .env file: {}", err);
        process::exit(1);
    });

    // TODO(xqft): read all env variables here
    let rpc_url = std::env::var("MINA_RPC_URL").unwrap_or_else(|err| {
        error!("couldn't read MINA_RPC_URL env. variable: {}", err);
        process::exit(1);
    });

    debug!("Executing Mina polling service");
    let mina_proof = mina_polling_service::query_and_serialize(&rpc_url).unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    debug!("Executing Aligned polling service");
    let verification_data = aligned_polling_service::submit(&mina_proof)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    debug!("Updating the bridge's smart contract");
    let pub_input = mina_proof.pub_input.unwrap_or_else(|| {
        error!("Missing public inputs from Mina proof");
        process::exit(1);
    });

    let new_state_hash = smart_contract_utility::update(verification_data, pub_input)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    info!(
        "Success! verified Mina state hash {} was stored in the bridge's smart contract",
        new_state_hash.encode_hex()
    );
}
