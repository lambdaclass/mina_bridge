use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use ethers::prelude::*;
use log::debug;

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum = MinaBridgeEthereumContract<Provider<Http>>;

pub async fn update(verification_data: AlignedVerificationData) -> Result<(), String> {
    let chain =
        match std::env::var("ETH_CHAIN")
            .expect("couldn't get ETH_CHAIN environment variable.")
            .as_str()
        {
            "devnet" => {
                debug!("Selected Anvil devnet chain.");
                Chain::Devnet
            }
            "holesky" => {
                debug!("Selected Holesky chain.");
                Chain::Holesky
            }
            _ => return Err(
                "Unrecognized chain, possible values for ETH_CHAIN are \"devnet\" and \"holesky\"."
                    .to_owned(),
            ),
        };

    let eth_rpc_url = if let Ok(eth_rpc_url) = std::env::var("ETH_RPC_URL") {
        eth_rpc_url
    } else if matches!(chain, Chain::Devnet) {
        debug!("Using default Ethereum RPC URL for devnet");
        "http://localhost:8545".to_string()
    } else {
        return Err("Chain selected is Holesky but couldn't read ETH_RPC_URL".to_string());
    };

    let bridge_eth_addr = if let Ok(bridge_eth_addr) = std::env::var("BRIDGE_ETH_ADDR") {
        bridge_eth_addr
    } else if matches!(chain, Chain::Devnet) {
        debug!("Using default bridge ethereum address for devnet");
        "0x7969c5eD335650692Bc04293B07F5BF2e7A673C0".to_string()
    } else {
        return Err("Chain selected is Holesky but couldn't read BRIDGE_ETH_ADDR".to_string());
    };
    let bridge_eth_addr = Address::from_str(&bridge_eth_addr).map_err(|err| err.to_string())?;

    let mina_bridge_contract = mina_bridge_contract(&eth_rpc_url, bridge_eth_addr)?;

    let AlignedVerificationData {
        verification_data_commitment,
        batch_merkle_root,
        batch_inclusion_proof,
        index_in_batch,
    } = verification_data;

    let merkle_proof = batch_inclusion_proof
        .merkle_path
        .clone()
        .into_iter()
        .flatten()
        .collect();

    let VerificationDataCommitment {
        proof_commitment,
        pub_input_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
    } = verification_data_commitment;

    mina_bridge_contract
        .update_last_verified_state(
            proof_commitment,
            pub_input_commitment,
            proving_system_aux_data_commitment,
            proof_generator_addr,
            batch_merkle_root,
            merkle_proof,
            index_in_batch.into(),
        )
        .await
        .map_err(|err| err.to_string())?;

    Ok(())
}

fn mina_bridge_contract(
    eth_rpc_url: &str,
    contract_address: Address,
) -> Result<MinaBridgeEthereum, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let client = Arc::new(eth_rpc_provider);
    Ok(MinaBridgeEthereum::new(contract_address, client))
}
