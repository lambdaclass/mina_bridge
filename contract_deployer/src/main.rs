use aligned_sdk::core::types::Chain;
use log::{debug, error, info};
use mina_bridge_core::{
    mina_polling_service::query_root,
    smart_contract_utility::{
        deploy_mina_bridge_contract, MinaBridgeConstructorArgs, SolStateHash,
    },
    utils::{
        constants::{
            ALIGNED_SM_DEVNET_ETH_ADDR, ALIGNED_SM_HOLESKY_ETH_ADDR, BRIDGE_TRANSITION_FRONTIER_LEN,
        },
        env::EnvironmentVariables,
        wallet_alloy::get_wallet,
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

    let aligned_sm_addr = match chain {
        Chain::Devnet => ALIGNED_SM_DEVNET_ETH_ADDR,
        Chain::Holesky => ALIGNED_SM_HOLESKY_ETH_ADDR,
        _ => todo!(),
    };

    let contract_constructor_args = MinaBridgeConstructorArgs::new(aligned_sm_addr, root_hash)
        .unwrap_or_else(|err| {
            error!("Failed to make constructor args for contract call: {err}");
            process::exit(1);
        });

    let wallet = get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("Failed to get wallet: {err}");
            process::exit(1);
        });
    deploy_mina_bridge_contract(&eth_rpc_url, contract_constructor_args, &wallet)
        .await
        .unwrap_or_else(|err| {
            error!("Failed to deploy contract: {err}");
            process::exit(1);
        });
}
