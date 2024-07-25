use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use ethers::prelude::*;

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum = MinaBridgeEthereumContract<Provider<Http>>;

pub async fn update(
    verification_data: AlignedVerificationData,
    chain: Chain,
    eth_rpc_url: &str,
) -> Result<(), String> {
    // TODO(xqft): contract address
    let contract_address = Address::from_str(match chain {
        Chain::Devnet => "0x0",
        _ => unimplemented!(),
    })
    .map_err(|err| err.to_string())?;

    let mina_bridge_contract = mina_bridge_contract(eth_rpc_url, contract_address)?;

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

    let call = mina_bridge_contract.update_last_verified_state(
        proof_commitment,
        pub_input_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        index_in_batch.into(),
    );

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
