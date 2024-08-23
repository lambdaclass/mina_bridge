use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use alloy::network::EthereumWallet;
use alloy::providers::ProviderBuilder;
use alloy::sol;
use ethers::{abi::AbiEncode, prelude::*};
use k256::ecdsa::SigningKey;
use kimchi::o1_utils::FieldHelpers;
use log::{debug, error, info};
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::StateHash;

use crate::utils::constants::{
    ANVIL_CHAIN_ID, BRIDGE_DEVNET_ETH_ADDR, BRIDGE_HOLESKY_ETH_ADDR, HOLESKY_CHAIN_ID,
};

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum =
    MinaBridgeEthereumContract<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>;

type MinaBridgeEthereumCallOnly = MinaBridgeEthereumContract<Provider<Http>>;

sol!(
    #[allow(clippy::too_many_arguments)]
    #[sol(rpc)]
    MinaBridge,
    "abi/MinaBridge.json"
);

pub struct MinaBridgeConstructorArgs {
    aligned_service_addr: alloy::primitives::Address,
    root_state_hash: alloy::primitives::FixedBytes<32>,
}

impl MinaBridgeConstructorArgs {
    pub fn new(aligned_service_addr: &str, root_state_hash: Vec<u8>) -> Result<Self, String> {
        let aligned_service_addr =
            alloy::primitives::Address::parse_checksummed(aligned_service_addr, None)
                .map_err(|err| err.to_string())?;
        let root_state_hash = alloy::primitives::FixedBytes(
            root_state_hash
                .try_into()
                .map_err(|_| "Could not convert root state hash into fixed array".to_string())?,
        );
        Ok(MinaBridgeConstructorArgs {
            aligned_service_addr,
            root_state_hash,
        })
    }
}

pub async fn update_tip(
    verification_data: AlignedVerificationData,
    pub_input: Vec<u8>,
    chain: &Chain,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
) -> Result<Fp, String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
        Chain::Holesky => BRIDGE_HOLESKY_ETH_ADDR,
        _ => {
            error!("Unimplemented Ethereum contract on selected chain");
            unimplemented!()
        }
    })
    .map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract(eth_rpc_url, bridge_eth_addr, chain, wallet)?;

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

    let update_call = mina_bridge_contract.update_tip_state(
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
        .get_tip_state_hash()
        .await
        .map_err(|err| err.to_string())?;

    Fp::from_bytes(&new_state_hash).map_err(|err| err.to_string())
}

pub async fn update_account(
    verification_data: AlignedVerificationData,
    pub_input: Vec<u8>,
    chain: &Chain,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
) -> Result<(), String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
        Chain::Holesky => BRIDGE_HOLESKY_ETH_ADDR,
        _ => {
            error!("Unimplemented Ethereum contract on selected chain");
            unimplemented!()
        }
    })
    .map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract(eth_rpc_url, bridge_eth_addr, chain, wallet)?;

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

    let update_call = mina_bridge_contract.update_account(
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

    Ok(())
}

pub async fn get_bridge_tip_hash(chain: &Chain, eth_rpc_url: &str) -> Result<StateHash, String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
        Chain::Holesky => BRIDGE_HOLESKY_ETH_ADDR,
        _ => {
            error!("Unimplemented Ethereum contract on selected chain");
            unimplemented!()
        }
    })
    .map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract_call_only(eth_rpc_url, bridge_eth_addr)?;

    debug!("Getting contract stored hash");
    let state_hash = mina_bridge_contract
        .get_tip_state_hash()
        .await
        .map_err(|err| err.to_string())?;

    Fp::from_bytes(&state_hash)
        .map_err(|_| "Failed to convert hash to Fp".to_string())
        .map(StateHash::from_fp)
}

pub async fn deploy_mina_bridge_contract(
    eth_rpc_url: &str,
    constructor_args: MinaBridgeConstructorArgs,
    wallet: &EthereumWallet,
) -> Result<alloy::primitives::Address, String> {
    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_http(reqwest::Url::parse(eth_rpc_url).map_err(|err| err.to_string())?);

    let MinaBridgeConstructorArgs {
        aligned_service_addr,
        root_state_hash,
    } = constructor_args;
    let contract = MinaBridge::deploy(&provider, aligned_service_addr, root_state_hash)
        .await
        .map_err(|err| err.to_string())?;
    let address = contract.address();

    info!(
        "Mina Bridge contract successfuly deployed with address {}",
        address
    );

    Ok(*address)
}

fn mina_bridge_contract(
    eth_rpc_url: &str,
    contract_address: Address,
    chain: &Chain,
    wallet: Wallet<SigningKey>,
) -> Result<MinaBridgeEthereum, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let chain_id = match chain {
        Chain::Devnet => ANVIL_CHAIN_ID,
        Chain::Holesky => HOLESKY_CHAIN_ID,
        _ => unimplemented!(),
    };
    let signer = SignerMiddleware::new(eth_rpc_provider, wallet.with_chain_id(chain_id));
    let client = Arc::new(signer);
    debug!("contract address: {contract_address}");
    Ok(MinaBridgeEthereum::new(contract_address, client))
}

fn mina_bridge_contract_call_only(
    eth_rpc_url: &str,
    contract_address: Address,
) -> Result<MinaBridgeEthereumCallOnly, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let client = Arc::new(eth_rpc_provider);
    Ok(MinaBridgeEthereumCallOnly::new(contract_address, client))
}
