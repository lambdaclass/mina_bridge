use core::{
    aligned_polling_service, mina_polling_service, smart_contract_utility,
    utils::env::EnvironmentVariables,
};
use ethers::abi::AbiEncode;
use log::{debug, error, info};
use std::process;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let EnvironmentVariables {
        rpc_url,
        chain,
        batcher_addr,
        batcher_eth_addr,
        eth_rpc_url,
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    debug!("Executing Mina polling service");
    let mina_proof = mina_polling_service::query_and_serialize(&rpc_url).unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    debug!("Executing Aligned polling service");
    let verification_data = aligned_polling_service::submit(
        &mina_proof,
        &chain,
        &batcher_addr,
        &batcher_eth_addr,
        &eth_rpc_url,
    )
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

    let verified_state_hash =
        smart_contract_utility::update(verification_data, pub_input, &chain, &eth_rpc_url)
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

    info!(
        "Success! verified Mina state hash {} was stored in the bridge's smart contract",
        verified_state_hash.encode_hex()
    );
}
