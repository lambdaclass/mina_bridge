use core::{
    mina_polling_service::query_root,
    smart_contract_utility::{deploy_mina_bridge_contract, MinaBridgeConstructorArgs},
    utils::{constants::ALIGNED_SM_DEVNET_ETH_ADDR, env::EnvironmentVariables},
};
use std::{process, str::FromStr};

use kimchi::turshi::helper::CairoFieldHelpers;
use log::{debug, error, info};
use mina_curves::pasta::Fp;
use o1_utils::FieldHelpers;

const BRIDGE_TRANSITION_FRONTIER_LEN: usize = 11;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Reading env. variables");
    let EnvironmentVariables {
        rpc_url,
        eth_rpc_url,
        ..
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let root_hash = query_root(&rpc_url, BRIDGE_TRANSITION_FRONTIER_LEN)
        .await
        .and_then(|dec| {
            let hash_fp =
                Fp::from_str(&dec).map_err(|_| "Failed to decode root hash".to_string())?;
            info!("Queried root state hash 0x{}", hash_fp.to_hex_be());
            Ok(hash_fp)
        })
        .map(|fp| fp.to_bytes())
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    let contract_constructor_args =
        MinaBridgeConstructorArgs::new(ALIGNED_SM_DEVNET_ETH_ADDR, root_hash).unwrap_or_else(
            |err| {
                error!("{}", err);
                process::exit(1);
            },
        );
    deploy_mina_bridge_contract(&eth_rpc_url, contract_constructor_args)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
}
