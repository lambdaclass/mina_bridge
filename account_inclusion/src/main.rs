use account_inclusion::{
    account, query_leaf_and_merkle_path, query_merkle_root, verify_merkle_proof,
};
use core::{smart_contract_utility::get_tip_state_hash, utils::env::EnvironmentVariables};
use kimchi::turshi::helper::CairoFieldHelpers;
use log::{debug, error, info};
use mina_tree::Account;
use std::process;

#[tokio::main]
async fn main() {
    for _ in 0..10 {
        let rand_account = Account::rand();
        let zkapp = &rand_account.zkapp;
        dbg!(zkapp.is_some());
        let verification_key = zkapp
            .as_ref()
            .and_then(|zkapp| zkapp.verification_key.clone());
        dbg!(verification_key.is_some());
        let rand_account_bytes = account::to_bytes(&rand_account);
        dbg!(rand_account_bytes.len());
    }

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

    let (leaf_hash, merkle_path) =
        query_leaf_and_merkle_path(&rpc_url, public_key).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    debug!("Leaf hash: {}", leaf_hash);

    let merkle_root = query_merkle_root(&rpc_url, state_hash).unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let is_account_included = verify_merkle_proof(leaf_hash, merkle_path, merkle_root);
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
