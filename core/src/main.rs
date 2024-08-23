use core::{
    aligned_polling_service, mina_polling_service, smart_contract_utility,
    utils::{env::EnvironmentVariables, wallet::get_wallet},
};
use kimchi::turshi::helper::CairoFieldHelpers;
use log::{debug, error, info};
use std::{process, time::SystemTime};

#[tokio::main]
async fn main() {
    let now = SystemTime::now();
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Reading env. variables");
    let EnvironmentVariables {
        rpc_url,
        chain,
        batcher_addr,
        batcher_eth_addr,
        eth_rpc_url,
        proof_generator_addr,
        keystore_path,
        private_key,
        save_proof,
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    debug!("Getting user wallet");
    let wallet = get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    debug!("Executing Mina polling service");
    let mina_proof = mina_polling_service::get_mina_proof_of_state(
        &rpc_url,
        &proof_generator_addr,
        &chain,
        &eth_rpc_url,
    )
    .await
    .unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    if save_proof {
        std::fs::write(
            "./protocol_state.pub",
            mina_proof.pub_input.as_ref().unwrap_or_else(|| {
                error!("Tried to save public inputs to file but they're missing");
                process::exit(1);
            }),
        )
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
        std::fs::write("./protocol_state.proof", &mina_proof.proof).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    }

    debug!("Executing Aligned polling service");
    let verification_data = aligned_polling_service::submit(
        &mina_proof,
        &chain,
        &batcher_addr,
        &batcher_eth_addr,
        &eth_rpc_url,
        wallet.clone(),
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
        smart_contract_utility::update(verification_data, pub_input, &chain, &eth_rpc_url, wallet)
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

    info!(
        "Success! verified Mina state hash 0x{} was stored in the bridge's smart contract",
        verified_state_hash.to_hex_be()
    );

    if let Ok(elapsed) = now.elapsed() {
        info!("Time spent: {} ms", elapsed.as_millis());
    }
}
