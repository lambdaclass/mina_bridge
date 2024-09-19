use log::{error, info};
use mina_bridge_core::{
    sdk::{is_state_verified, validate_account, verify_state},
    utils::{env::EnvironmentVariables, wallet::get_wallet},
};
use std::process;

const MINA_ZKAPP_ADDRESS: &str = "B62qmpq1JBejZYDQrZwASPRM5oLXW346WoXgbApVf5HJZXMWFPWFPuA";

#[tokio::main]
async fn main() {
    let mut args = std::env::args().collect::<Vec<_>>();

    // state that includes the zkApp update transaction
    let state_hash = if args.is_empty() {
        error!("Missing state hash argument");
        process::exit(1);
    } else {
        args.remove(0)
    };

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

    let is_state_verified = is_state_verified(&state_hash, &chain, &eth_rpc_url)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    if !is_state_verified {
        info!("State that includes the zkApp tx isn't verified. Bridging latest chain...");
        verify_state(
            &rpc_url,
            &chain,
            &batcher_addr,
            &batcher_eth_addr,
            &eth_rpc_url,
            &proof_generator_addr,
            wallet.clone(),
            false,
        )
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    }

    validate_account(
        MINA_ZKAPP_ADDRESS,
        &state_hash,
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
