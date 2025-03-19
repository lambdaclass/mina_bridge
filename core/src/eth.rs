use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Network, VerificationDataCommitment};
use alloy::network::EthereumWallet;
use alloy::providers::ProviderBuilder;
use alloy::sol;
use ethers::{abi::AbiEncode, prelude::*};
use k256::ecdsa::SigningKey;
use log::{debug, info};
use mina_p2p_messages::v2::StateHash;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use crate::{
    proof::{account_proof::MinaAccountPubInputs, state_proof::MinaStatePubInputs},
    sol::serialization::SolSerialize,
    utils::constants::{ANVIL_CHAIN_ID, BRIDGE_TRANSITION_FRONTIER_LEN, HOLESKY_CHAIN_ID},
};

abigen!(
    MinaStateSettlementExampleEthereumContract,
    "abi/MinaStateSettlementExample.json"
);
abigen!(
    MinaAccountValidationExampleEthereumContract,
    "abi/MinaAccountValidationExample.json"
);

type MinaStateSettlementExampleEthereum = MinaStateSettlementExampleEthereumContract<
    SignerMiddleware<Provider<Http>, Wallet<SigningKey>>,
>;

type MinaStateSettlementExampleEthereumCallOnly =
    MinaStateSettlementExampleEthereumContract<Provider<Http>>;
type MinaAccountValidationExampleEthereumCallOnly =
    MinaAccountValidationExampleEthereumContract<Provider<Http>>;

sol!(
    #[allow(clippy::too_many_arguments)]
    #[sol(rpc)]
    MinaStateSettlementExample,
    "abi/MinaStateSettlementExample.json"
);

sol!(
    #[allow(clippy::too_many_arguments)]
    #[sol(rpc)]
    MinaAccountValidationExample,
    "abi/MinaAccountValidationExample.json"
);

// Define constant values that will be used for gas limits and calculations
const MAX_GAS_LIMIT_VALUE: u64 = 1_000_000; // Maximum allowed gas for a transaction
const MAX_GAS_PRICE_GWEI: u64 = 300; // Maximum allowed gas price in Gwei
const GAS_ESTIMATE_MARGIN: u64 = 110; // Safety margin (110 means 110%, or +10%)

/// Wrapper of Mina Ledger hash for Ethereum
#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct SolStateHash(#[serde_as(as = "SolSerialize")] pub StateHash);

/// Arguments of the Mina State Settlement Example Ethereum Contract constructor:
///
/// - `aligned_service_addr`: Address of the Aligned Service Manager Ethereum Contract
/// - `root_state_hash`: Root state hash of the Mina transition frontier
pub struct MinaStateSettlementExampleConstructorArgs {
    aligned_service_addr: alloy::primitives::Address,
    root_state_hash: alloy::primitives::FixedBytes<32>,
}

/// Arguments of the Mina Account Validation Example Ethereum Contract constructor:
///
/// - `aligned_service_addr`: Address of the Aligned Service Manager Ethereum Contract
pub struct MinaAccountValidationExampleConstructorArgs {
    aligned_service_addr: alloy::primitives::Address,
}

impl MinaStateSettlementExampleConstructorArgs {
    pub fn new(aligned_service_addr: &str, root_state_hash: Vec<u8>) -> Result<Self, String> {
        let aligned_service_addr =
            alloy::primitives::Address::parse_checksummed(aligned_service_addr, None)
                .map_err(|err| err.to_string())?;
        let root_state_hash = alloy::primitives::FixedBytes(
            root_state_hash
                .try_into()
                .map_err(|_| "Could not convert root state hash into fixed array".to_string())?,
        );
        Ok(Self {
            aligned_service_addr,
            root_state_hash,
        })
    }
}

impl MinaAccountValidationExampleConstructorArgs {
    pub fn new(aligned_service_addr: &str) -> Result<Self, String> {
        let aligned_service_addr =
            alloy::primitives::Address::parse_checksummed(aligned_service_addr, None)
                .map_err(|err| err.to_string())?;
        Ok(Self {
            aligned_service_addr,
        })
    }
}

// Main function that validates gas parameters
// Takes provider (connection to Ethereum) and estimated_gas as parameters
async fn validate_gas_params(
    provider: &Provider<Http>,
    estimated_gas: U256,
) -> Result<U256, String> {
    // Query the current network gas price
    let current_gas_price = provider
        .get_gas_price()
        .await
        .map_err(|err| err.to_string())?;

    // Convert gas price from Wei to Gwei by dividing by 1_000_000_000
    let gas_price_gwei = current_gas_price
        .checked_div(U256::from(1_000_000_000))
        .ok_or("Gas price calculation overflow")?;

    // Check if the current gas price is above our maximum allowed price
    if gas_price_gwei > U256::from(MAX_GAS_PRICE_GWEI) {
        return Err(format!(
            "Gas price too high: {} gwei (max: {} gwei)",
            gas_price_gwei, MAX_GAS_PRICE_GWEI
        ));
    }

    // Calculate gas limit with safety margin:
    // 1. Multiply estimated gas by 110 (for 10% extra)
    // 2. Divide by 100 to get the final value
    let gas_with_margin = estimated_gas
        .checked_mul(U256::from(GAS_ESTIMATE_MARGIN))
        .and_then(|v| v.checked_div(U256::from(100)))
        .ok_or("Gas margin calculation overflow")?;

    // Check if our gas limit with margin is above maximum allowed gas
    if gas_with_margin > U256::from(MAX_GAS_LIMIT_VALUE) {
        return Err(format!(
            "Estimated gas too high: {} (max: {})",
            gas_with_margin, MAX_GAS_LIMIT_VALUE
        ));
    }

    // If all checks pass, return the gas limit with safety margin
    Ok(gas_with_margin)
}

pub async fn update_chain(
    verification_data: AlignedVerificationData,
    pub_input: &MinaStatePubInputs,
    network: &Network,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
    contract_addr: &str,
    batcher_payment_service: &str,
) -> Result<(), String> {
    let provider = Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let bridge_eth_addr = Address::from_str(contract_addr).map_err(|err| err.to_string())?;

    let serialized_pub_input = bincode::serialize(pub_input)
        .map_err(|err| format!("Failed to serialize public inputs: {err}"))?;

    let batcher_payment_service = Address::from_str(batcher_payment_service)
        .map_err(|err| format!("Failed to parse batcher payment service address: {err}"))?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract(eth_rpc_url, bridge_eth_addr, network, wallet)?;

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

    let update_call = mina_bridge_contract.update_chain(
        proof_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        index_in_batch.into(),
        serialized_pub_input.into(),
        batcher_payment_service,
    );
    // update call reverts if batch is not valid or proof isn't included in it.

    let estimated_gas = update_call
        .estimate_gas()
        .await
        .map_err(|err| err.to_string())?;

    info!("Estimated gas cost: {}", estimated_gas);

    // Validate gas parameters and get safe gas limit
    let gas_limit = validate_gas_params(&provider, estimated_gas).await?;
    let update_call_with_gas_limit = update_call.gas(gas_limit);

    let pending_tx = update_call_with_gas_limit
        .send()
        .await
        .map_err(|err| err.to_string())?;
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

    info!("Checking that the state hashes were stored correctly..");

    // TODO(xqft): do the same for ledger hashes
    debug!("Getting network state hashes");
    let new_network_state_hashes = get_bridge_chain_state_hashes(contract_addr, eth_rpc_url)
        .await
        .map_err(|err| err.to_string())?;

    if new_network_state_hashes != pub_input.candidate_chain_state_hashes {
        return Err("Stored network state hashes don't match the candidate's".to_string());
    }

    let tip_state_hash = new_network_state_hashes
        .last()
        .ok_or("Failed to get tip state hash".to_string())?
        .clone();
    info!("Successfuly updated smart contract to verified network of tip {tip_state_hash}");

    Ok(())
}

pub async fn get_bridge_tip_hash(
    contract_addr: &str,
    eth_rpc_url: &str,
) -> Result<SolStateHash, String> {
    let bridge_eth_addr = Address::from_str(contract_addr).map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract_call_only(eth_rpc_url, bridge_eth_addr)?;

    let state_hash_bytes = mina_bridge_contract
        .get_tip_state_hash()
        .await
        .map_err(|err| err.to_string())?;

    let state_hash: SolStateHash = bincode::deserialize(&state_hash_bytes)
        .map_err(|err| format!("Failed to deserialize bridge tip state hash: {err}"))?;
    info!("Retrieved bridge tip state hash: {}", state_hash.0,);

    Ok(state_hash)
}

pub async fn get_bridge_chain_state_hashes(
    contract_addr: &str,
    eth_rpc_url: &str,
) -> Result<[StateHash; BRIDGE_TRANSITION_FRONTIER_LEN], String> {
    let bridge_eth_addr = Address::from_str(contract_addr).map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
    let mina_bridge_contract = mina_bridge_contract_call_only(eth_rpc_url, bridge_eth_addr)?;

    mina_bridge_contract
        .get_chain_state_hashes()
        .await
        .map_err(|err| format!("Could not call contract for state hashes: {err}"))
        .and_then(|hashes| {
            hashes
                .into_iter()
                .map(|hash| {
                    bincode::deserialize::<SolStateHash>(&hash)
                        .map_err(|err| format!("Failed to deserialize network state hashes: {err}"))
                        .map(|hash| hash.0)
                })
                .collect::<Result<Vec<_>, _>>()
        })
        .and_then(|hashes| {
            hashes
                .try_into()
                .map_err(|_| "Failed to convert network state hashes vec into array".to_string())
        })
}

pub async fn validate_account(
    verification_data: AlignedVerificationData,
    pub_input: &MinaAccountPubInputs,
    eth_rpc_url: &str,
    contract_addr: &str,
    batcher_payment_service: &str,
) -> Result<(), String> {
    let provider = Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let bridge_eth_addr = Address::from_str(contract_addr).map_err(|err| err.to_string())?;

    debug!("Creating contract instance");

    let contract = mina_account_validation_contract_call_only(eth_rpc_url, bridge_eth_addr)?;

    let serialized_pub_input = bincode::serialize(pub_input)
        .map_err(|err| format!("Failed to serialize public inputs: {err}"))?;

    let batcher_payment_service = Address::from_str(batcher_payment_service)
        .map_err(|err| format!("Failed to parse batcher payment service address: {err}"))?;

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

    debug!("Validating account");

    let aligned_args = AlignedArgs {
        proof_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        verification_data_batch_index: index_in_batch.into(),
        pub_input: serialized_pub_input.into(),
        batcher_payment_service,
    };

    let call = contract.validate_account(aligned_args);
    let estimated_gas = call.estimate_gas().await.map_err(|err| err.to_string())?;

    info!("Estimated account verification gas cost: {estimated_gas}");

    let gas_limit = validate_gas_params(&provider, estimated_gas).await?;

    call.gas(gas_limit).await.map_err(|err| err.to_string())?;

    Ok(())
}

pub async fn deploy_mina_bridge_example_contract(
    eth_rpc_url: &str,
    constructor_args: &MinaStateSettlementExampleConstructorArgs,
    wallet: &EthereumWallet,
    is_state_proof_from_devnet: bool,
) -> Result<alloy::primitives::Address, String> {
    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_http(reqwest::Url::parse(eth_rpc_url).map_err(|err| err.to_string())?);

    let MinaStateSettlementExampleConstructorArgs {
        aligned_service_addr,
        root_state_hash,
    } = constructor_args;
    let contract = MinaStateSettlementExample::deploy(
        &provider,
        *aligned_service_addr,
        *root_state_hash,
        is_state_proof_from_devnet,
    )
    .await
    .map_err(|err| err.to_string())?;
    let address = contract.address();

    let network = if is_state_proof_from_devnet {
        "Devnet"
    } else {
        "Mainnet"
    };

    info!(
        "Mina {} Bridge example contract successfuly deployed with address {}",
        network, address
    );
    info!(
        "Set STATE_SETTLEMENT_ETH_ADDR={} if using Mina {}",
        address, network
    );

    Ok(*address)
}

pub async fn deploy_mina_account_validation_example_contract(
    eth_rpc_url: &str,
    constructor_args: MinaAccountValidationExampleConstructorArgs,
    wallet: &EthereumWallet,
) -> Result<alloy::primitives::Address, String> {
    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_http(reqwest::Url::parse(eth_rpc_url).map_err(|err| err.to_string())?);

    let MinaAccountValidationExampleConstructorArgs {
        aligned_service_addr,
    } = constructor_args;
    let contract = MinaAccountValidationExample::deploy(&provider, aligned_service_addr)
        .await
        .map_err(|err| err.to_string())?;
    let address = contract.address();

    info!(
        "Mina Account Validation example contract successfuly deployed with address {}",
        address
    );
    info!("Set ACCOUNT_VALIDATION_ETH_ADDR={}", address);

    Ok(*address)
}

fn mina_bridge_contract(
    eth_rpc_url: &str,
    contract_address: Address,
    network: &Network,
    wallet: Wallet<SigningKey>,
) -> Result<MinaStateSettlementExampleEthereum, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let network_id = match network {
        Network::Devnet => ANVIL_CHAIN_ID,
        Network::Holesky => HOLESKY_CHAIN_ID,
        _ => unimplemented!(),
    };
    let signer = SignerMiddleware::new(eth_rpc_provider, wallet.with_chain_id(network_id));
    let client = Arc::new(signer);
    debug!("contract address: {contract_address}");
    Ok(MinaStateSettlementExampleEthereum::new(
        contract_address,
        client,
    ))
}

fn mina_bridge_contract_call_only(
    eth_rpc_url: &str,
    contract_address: Address,
) -> Result<MinaStateSettlementExampleEthereumCallOnly, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let client = Arc::new(eth_rpc_provider);
    Ok(MinaStateSettlementExampleEthereumCallOnly::new(
        contract_address,
        client,
    ))
}

fn mina_account_validation_contract_call_only(
    eth_rpc_url: &str,
    contract_address: Address,
) -> Result<MinaAccountValidationExampleEthereumCallOnly, String> {
    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let client = Arc::new(eth_rpc_provider);
    Ok(MinaAccountValidationExampleEthereumCallOnly::new(
        contract_address,
        client,
    ))
}
