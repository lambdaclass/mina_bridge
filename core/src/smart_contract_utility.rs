use std::str::FromStr;
use std::sync::Arc;

use aligned_sdk::core::types::{AlignedVerificationData, Chain, VerificationDataCommitment};
use ethers::{abi::AbiEncode, prelude::*};
use k256::ecdsa::SigningKey;
use log::{debug, info};

abigen!(MinaBridgeEthereumContract, "abi/MinaBridge.json");

type MinaBridgeEthereum =
    MinaBridgeEthereumContract<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>;

// TODO(xqft): define in constants.rs
const ANVIL_PRIVATE_KEY: &str = "2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"; // Anvil address 9
const ANVIL_CHAIN_ID: u64 = 31337;

pub async fn update(
    verification_data: AlignedVerificationData,
    pub_input: Vec<u8>,
) -> Result<U256, String> {
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

    let bridge_eth_addr = Address::from_str(match chain {
        Chain::Devnet => "0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35",
        _ => unimplemented!(),
    })
    .map_err(|err| err.to_string())?;

    debug!("Creating contract instance");
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
        proving_system_aux_data_commitment,
        proof_generator_addr,
        ..
    } = verification_data_commitment;

    debug!("Calling updateLastVerifiedState()");
    let update_call = mina_bridge_contract.update_last_verified_state(
        proof_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        index_in_batch.into(),
        pub_input.into(),
    );

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

    // call reverts if batch is not valid.
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
