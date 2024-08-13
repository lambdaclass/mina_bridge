use account_inclusion::verify_merkle_proof;
use core::{
    mina_polling_service::query_merkle, smart_contract_utility::get_tip_state_hash,
    utils::env::EnvironmentVariables,
};
use kimchi::turshi::helper::CairoFieldHelpers;
use log::{debug, error, info};
use mina_p2p_messages::v2::StateHash;
use std::process;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Reading env. variables");
    let EnvironmentVariables {
        rpc_url,
        chain,
        eth_rpc_url,
        ..
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let args: Vec<String> = std::env::args().collect();
    let public_key = args.get(1).unwrap_or_else(|| {
        error!("Couldn't get public_key from command arguments.");
        process::exit(1);
    });

    debug!("Getting tip state hash");
    let state_hash = get_tip_state_hash(&chain, &eth_rpc_url)
        .await
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    info!(
        "Retrieved bridge tip state hash: 0x{}",
        state_hash.to_hex_be()
    );

    let (merkle_root, merkle_leaf, merkle_path) = query_merkle(
        &rpc_url,
        &StateHash::from_fp(state_hash).to_string(),
        public_key,
    )
    .await
    .unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let is_account_included = verify_merkle_proof(merkle_leaf, merkle_path, merkle_root);
    if is_account_included {
        info!(
            "Account {} is included in the latest bridged Mina state.",
            public_key
        );
    } else {
        info!(
            "Account {} is not included in the latest bridged Mina state.",
            public_key
        )
    }
}
