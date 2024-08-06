use std::sync::Arc;
use std::{path::PathBuf, str::FromStr};

use abi::{Token, Tokenize};
use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use ethers::{
    abi::AbiEncode,
    prelude::*,
    solc::{Artifact, Project, ProjectPathsConfig},
};
use k256::ecdsa::SigningKey;
use kimchi::o1_utils::FieldHelpers;
use log::{debug, error, info};
use mina_curves::pasta::Fp;

use crate::utils::constants::{ANVIL_CHAIN_ID, BRIDGE_DEVNET_ETH_ADDR};

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum =
    MinaBridgeEthereumContract<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>;

type MinaBridgeEthereumCallOnly = MinaBridgeEthereumContract<Provider<Http>>;

pub struct MinaBridgeConstructorArgs {
    aligned_service_addr: Address,
    root_state_hash: Vec<u8>,
}

impl MinaBridgeConstructorArgs {
    pub fn new(
        aligned_service_addr: Address,
        root_state_hash: Vec<u8>,
    ) -> MinaBridgeConstructorArgs {
        MinaBridgeConstructorArgs {
            aligned_service_addr,
            root_state_hash,
        }
    }
}

impl Tokenize for MinaBridgeConstructorArgs {
    fn into_tokens(self) -> Vec<abi::Token> {
        vec![
            Token::Address(self.aligned_service_addr),
            Token::FixedBytes(self.root_state_hash),
        ]
    }
}

pub async fn update(
    verification_data: AlignedVerificationData,
    pub_input: Vec<u8>,
    chain: &Chain,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
) -> Result<Fp, String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
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

pub async fn get_tip_state_hash(chain: &Chain, eth_rpc_url: &str) -> Result<Fp, String> {
    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
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

    Fp::from_bytes(&state_hash).map_err(|_| "Failed to convert hash to Fp".to_string())
}

pub async fn deploy_mina_bridge_contract(
    chain: &Chain,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
    constructor_args: MinaBridgeConstructorArgs,
) -> Result<MinaBridgeEthereum, String> {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .ok_or("Could not get project root path")?
        .join("contract");
    let paths = ProjectPathsConfig::builder()
        .root(&root)
        .sources(&root)
        .build()
        .unwrap();
    let project = Project::builder()
        .paths(paths)
        .ephemeral()
        .no_artifacts()
        .build()
        .unwrap();
    let output = project.compile().unwrap();
    let contract = output
        .find_first("MinaBridge")
        .ok_or("Could not get MinaBridge contract")?
        .clone();
    let (abi, bytecode, _) = contract.into_parts();

    let eth_rpc_provider =
        Provider::<Http>::try_from(eth_rpc_url).map_err(|err| err.to_string())?;
    let chain_id = match chain {
        Chain::Devnet => ANVIL_CHAIN_ID,
        _ => unimplemented!(),
    };
    let signer = SignerMiddleware::new(eth_rpc_provider, wallet.with_chain_id(chain_id));
    let client = Arc::new(signer);

    let factory = ContractFactory::new(abi.unwrap(), bytecode.unwrap(), client.clone());

    let contract = factory
        .deploy(constructor_args)
        .map_err(|err| err.to_string())?
        .send()
        .await
        .map_err(|err| err.to_string())?;

    info!(
        "Mina Bridge contract successfuly deployed with address {}!",
        contract.address()
    );

    Ok(MinaBridgeEthereum::new(contract.address(), client))
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
        _ => unimplemented!(),
    };
    let signer = SignerMiddleware::new(eth_rpc_provider, wallet.with_chain_id(chain_id));
    let client = Arc::new(signer);
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
