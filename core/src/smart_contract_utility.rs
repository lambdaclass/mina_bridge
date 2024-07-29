use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use ethers::{abi::AbiEncode, prelude::*};
use k256::ecdsa::SigningKey;
use log::{debug, error, info};

use crate::utils::constants::{ANVIL_CHAIN_ID, ANVIL_PRIVATE_KEY, BRIDGE_DEVNET_ETH_ADDR};

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum =
    MinaBridgeEthereumContract<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>;

pub async fn update(
    verification_data: AlignedVerificationData,
    pub_input: Vec<u8>,
    chain: &Chain,
    eth_rpc_url: &str,
) -> Result<U256, String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
        _ => {
            error!("Unimplemented Ethereum contract on selected chain");
            unimplemented!()
        }
    })
    .map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract(eth_rpc_url, bridge_eth_addr)?;

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
        proving_system_aux_data_commitment,
        proof_generator_addr,
        ..
    } = verification_data_commitment;

    debug!("Updating contract");

    let update_call = mina_bridge_contract.update_last_verified_state(
        proof_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        index_in_batch.into(),
        pub_input.into(),
    );
    // update call reverts if batch is not valid or proof isn't included in it.

    info!(
        "Estimated gas cost: {}",
        update_call
            .estimate_gas()
            .await
            .map_err(|err| err.to_string())?
    );

    let pending_tx = update_call.send().await.map_err(|err| err.to_string())?;
    info!(
        "Transaction {} was submitted and is now pending",
        pending_tx.tx_hash().encode_hex()
    );

    let receipt = pending_tx
        .await
        .map_err(|err| err.to_string())?
        .ok_or("Missing transaction receipt")?;

    info!(
        "Transaction mined! final gas cost: {}",
        receipt.gas_used.ok_or("Missing gas used")?
    );

    debug!("Getting contract stored hash");
    let new_state_hash = mina_bridge_contract
        .get_last_verified_state_hash()
        .await
        .map_err(|err| err.to_string())?;

    Ok(new_state_hash)
}

fn mina_bridge_contract(
    eth_rpc_url: &str,
    contract_address: Address,
) -> Result<MinaBridgeEthereum, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let wallet = LocalWallet::from_str(ANVIL_PRIVATE_KEY).expect("failed to create wallet");
    let signer = SignerMiddleware::new(eth_rpc_provider, wallet.with_chain_id(ANVIL_CHAIN_ID));
    let client = Arc::new(signer);
    Ok(MinaBridgeEthereum::new(contract_address, client))
}
