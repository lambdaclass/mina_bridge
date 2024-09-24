use log::{debug, error, info};
use mina_bridge_core::{
    mina_polling_service::query_root,
    smart_contract_utility::{
        deploy_mina_account_validation_contract, deploy_mina_bridge_contract,
        MinaAccountValidationConstructorArgs, MinaBridgeConstructorArgs, SolStateHash,
    },
    utils::{
        constants::BRIDGE_TRANSITION_FRONTIER_LEN, contract::get_aligned_sm_contract_addr,
        env::EnvironmentVariables, wallet_alloy::get_wallet,
    },
};
use std::process;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Reading env. variables");
    let EnvironmentVariables {
        rpc_url,
        eth_rpc_url,
        chain,
        private_key,
        keystore_path,
        ..
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let root_hash = query_root(&rpc_url, BRIDGE_TRANSITION_FRONTIER_LEN)
        .await
        .unwrap_or_else(|err| {
            error!("Failed to query root state hash: {err}");
            process::exit(1);
        });
    info!(
        "Queried root state hash {root_hash} for chain of length {BRIDGE_TRANSITION_FRONTIER_LEN}"
    );
    let root_hash = bincode::serialize(&SolStateHash(root_hash)).unwrap_or_else(|err| {
        error!("Failed to serialize root state hash: {err}");
        process::exit(1);
    });

    let aligned_sm_addr = get_aligned_sm_contract_addr(&chain).unwrap_or_else(|err| {
        error!("{err}");
        process::exit(1);
    });

    let bridge_constructor_args = MinaBridgeConstructorArgs::new(&aligned_sm_addr, root_hash)
        .unwrap_or_else(|err| {
            error!("Failed to make constructor args for bridge contract call: {err}");
            process::exit(1);
        });
    let account_constructor_args = MinaAccountValidationConstructorArgs::new(&aligned_sm_addr)
        .unwrap_or_else(|err| {
            error!("Failed to make constructor args for account contract call: {err}");
            process::exit(1);
        });

    let wallet = get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("Failed to get wallet: {err}");
            process::exit(1);
        });

    deploy_mina_bridge_contract(&eth_rpc_url, bridge_constructor_args, &wallet)
        .await
        .unwrap_or_else(|err| {
            error!("Failed to deploy contract: {err}");
            process::exit(1);
        });

    deploy_mina_account_validation_contract(&eth_rpc_url, account_constructor_args, &wallet)
        .await
        .unwrap_or_else(|err| {
            error!("Failed to deploy contract: {err}");
            process::exit(1);
        });
}
