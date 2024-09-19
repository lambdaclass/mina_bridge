use log::{error, info};
use mina_bridge_core::{
    sdk::{get_bridged_chain_tip_state_hash, update_bridge_chain, validate_account},
    utils::{env::EnvironmentVariables, wallet::get_wallet},
};
use std::process;

const MINA_ZKAPP_ADDRESS: &str = "B62qmpq1JBejZYDQrZwASPRM5oLXW346WoXgbApVf5HJZXMWFPWFPuA";

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let EnvironmentVariables {
        rpc_url,
        chain,
        batcher_addr,
        batcher_eth_addr,
        eth_rpc_url,
        proof_generator_addr,
        keystore_path,
        private_key,
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let wallet = get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    // We could check if the specific block containing the tx is already verified, before
    // updating the bridge's chain.
    // let is_state_verified = is_state_verified(&state_hash, &chain, &eth_rpc_url)
    //     .await
    //     .unwrap_or_else(|err| {
    //         error!("{}", err);
    //         process::exit(1);
    //     });

    // if !is_state_verified {
    //     info!("State that includes the zkApp tx isn't verified. Bridging latest chain...");
    let state_verification_result = update_bridge_chain(
        &rpc_url,
        &chain,
        &batcher_addr,
        &batcher_eth_addr,
        &eth_rpc_url,
        &proof_generator_addr,
        wallet.clone(),
        false,
    )
    .await;

    match state_verification_result {
        Err(err) if err == "Latest chain is already verified" => {
            info!("Bridge chain is up to date, won't verify new states.")
        }
        Err(err) => {
            error!("{}", err);
            process::exit(1);
        }
        _ => {}
    }
    // }

    let tip_state_hash = get_bridged_chain_tip_state_hash(&chain, &eth_rpc_url)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    validate_account(
        MINA_ZKAPP_ADDRESS,
        &tip_state_hash,
        &rpc_url,
        &chain,
        &batcher_addr,
        &batcher_eth_addr,
        &eth_rpc_url,
        &proof_generator_addr,
        wallet,
        false,
    )
    .await
    .unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });
}
