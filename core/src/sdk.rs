use std::str::FromStr;

use aligned_sdk::core::types::{AlignedVerificationData, Network, VerificationDataCommitment};
use ethers::{core::k256::ecdsa::SigningKey, signers::Wallet};
use log::debug;
use mina_p2p_messages::v2::StateHash;

use crate::{
    aligned::submit,
    eth::{self, get_bridge_chain_state_hashes, update_chain},
    mina::{get_mina_proof_of_account, get_mina_proof_of_state},
    proof::MinaProof,
};

/// Minimum data needed to verify a Mina account on Ethereum.
/// To use this struct you need to:
///
/// 1. Deploy an Ethereum contract that refers to a deployed Mina zkapp.
///    The contract functions that mimic the ones from Mina should recieve this struct's fields as arguments.
///    The contract's functions should verify that the referred Mina account is included in the
///    ledger hash and also run the same logic that the function of the Mina zkapp the Ethereum contract is
///    mimicing.
/// 1. Call `validate_account` function which creates an instance of this struct.
/// 1. Send a transaction that calls the verification function and pass the struct fields as arguments.
///
/// For reference see [SudokuValidity](https://github.com/lambdaclass/mina_bridge/blob/7f2fa1f0eac39499ff2ed3ed2d989ea7314805e3/example/eth_contract/src/SudokuValidity.sol)
/// example contract and [how can it be called](https://github.com/lambdaclass/mina_bridge/blob/7f2fa1f0eac39499ff2ed3ed2d989ea7314805e3/example/app/src/main.rs#L175-L200).
pub struct AccountVerificationData {
    pub proof_commitment: [u8; 32],
    pub proving_system_aux_data_commitment: [u8; 32],
    pub proof_generator_addr: [u8; 20],
    pub batch_merkle_root: [u8; 32],
    pub merkle_proof: Vec<u8>,
    pub verification_data_batch_index: usize,
    pub pub_input: Vec<u8>,
}

pub async fn is_state_verified(
    hash: &str,
    state_settlement_addr: &str,
    eth_rpc_url: &str,
) -> Result<bool, String> {
    let chain_state_hashes =
        get_bridge_chain_state_hashes(state_settlement_addr, eth_rpc_url).await?;
    let hash = StateHash::from_str(hash)
        .map_err(|err| format!("Failed to convert hash string to state hash: {err}"))?;
    Ok(chain_state_hashes.contains(&hash))
}

pub async fn get_bridged_chain_tip_state_hash(
    state_settlement_addr: &str,
    eth_rpc_url: &str,
) -> Result<String, String> {
    get_bridge_chain_state_hashes(state_settlement_addr, eth_rpc_url)
        .await
        .map(|hashes| hashes.last().unwrap().to_string())
}

#[allow(clippy::too_many_arguments)]
pub async fn update_bridge_chain(
    rpc_url: &str,
    network: &Network,
    state_settlement_addr: &str,
    batcher_addr: &str,
    eth_rpc_url: &str,
    proof_generator_addr: &str,
    wallet: Wallet<SigningKey>,
    batcher_payment_service: &str,
    is_state_proof_from_devnet: bool,
    save_proof: bool,
) -> Result<(), String> {
    let (proof, pub_input) = get_mina_proof_of_state(
        rpc_url,
        eth_rpc_url,
        state_settlement_addr,
        is_state_proof_from_devnet,
    )
    .await?;

    if pub_input.candidate_chain_state_hashes
        == get_bridge_chain_state_hashes(state_settlement_addr, eth_rpc_url).await?
    {
        debug!("The bridge chain is updated to the candidate chain");
        return Err("Latest chain is already verified".to_string());
    }

    let verification_data = submit(
        MinaProof::State((proof, pub_input.clone())),
        network,
        proof_generator_addr,
        batcher_addr,
        eth_rpc_url,
        wallet.clone(),
        save_proof,
    )
    .await?;

    update_chain(
        verification_data,
        &pub_input,
        network,
        eth_rpc_url,
        wallet,
        state_settlement_addr,
        batcher_payment_service,
    )
    .await?;

    Ok(())
}

#[allow(clippy::too_many_arguments)]
pub async fn validate_account(
    public_key: &str,
    state_hash: &str,
    rpc_url: &str,
    network: &Network,
    account_validation_addr: &str,
    batcher_addr: &str,
    eth_rpc_url: &str,
    proof_generator_addr: &str,
    batcher_payment_service: &str,
    wallet: Wallet<SigningKey>,
    save_proof: bool,
) -> Result<AccountVerificationData, String> {
    let (proof, pub_input) = get_mina_proof_of_account(public_key, state_hash, rpc_url).await?;

    let verification_data = submit(
        MinaProof::Account((proof, pub_input.clone())),
        network,
        proof_generator_addr,
        batcher_addr,
        eth_rpc_url,
        wallet.clone(),
        save_proof,
    )
    .await?;

    eth::validate_account(
        verification_data.clone(),
        &pub_input,
        eth_rpc_url,
        account_validation_addr,
        batcher_payment_service,
    )
    .await?;

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

    Ok(AccountVerificationData {
        proof_commitment,
        proving_system_aux_data_commitment,
        proof_generator_addr,
        batch_merkle_root,
        merkle_proof,
        verification_data_batch_index: index_in_batch,
        pub_input: bincode::serialize(&pub_input)
            .map_err(|err| format!("Failed to encode public inputs: {err}"))?,
    })
}
