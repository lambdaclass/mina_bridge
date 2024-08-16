use std::path::PathBuf;

use aligned_sdk::{
    core::types::{AlignedVerificationData, Chain, VerificationData},
    sdk::{get_next_nonce, submit_and_wait},
};
use ethers::{
    core::k256::ecdsa::SigningKey,
    signers::{Signer, Wallet},
    types::{Address, U256},
};
use log::info;

/// Submits a Mina proof to Aligned's batcher and waits until the batch is verified.
pub async fn submit(
    mina_proof: &VerificationData,
    chain: &Chain,
    batcher_addr: &str,
    batcher_eth_addr: &str,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
) -> Result<AlignedVerificationData, String> {
    let nonce = get_nonce(eth_rpc_url, wallet.address(), batcher_eth_addr).await?;

    info!("Submitting Mina proof into Aligned and waiting for the batch to be verified...");
    let aligned_verification_data = submit_and_wait(
        batcher_addr,
        eth_rpc_url,
        chain.to_owned(),
        mina_proof,
        wallet,
        nonce,
    )
    .await
    .map_err(|err| err.to_string())?;

    if let Some(aligned_verification_data) = aligned_verification_data {
        info!("Batch was succesfully verified!");
        Ok(aligned_verification_data)
    } else {
        Err("Verification data was not returned when submitting the proof, possibly because the connection was closed sooner than expected.".to_string())
    }
}

async fn get_nonce(
    eth_rpc_url: &str,
    address: Address,
    batcher_eth_addr: &str,
) -> Result<U256, String> {
    let nonce = get_next_nonce(eth_rpc_url, address, batcher_eth_addr)
        .await
        .map_err(|err| err.to_string())?;

    let nonce_file = &PathBuf::from(format!("nonce_{:?}.bin", address));

    let local_nonce = std::fs::read(nonce_file).unwrap_or(vec![0u8; 32]);
    let local_nonce = U256::from_big_endian(local_nonce.as_slice());

    let nonce = if local_nonce > nonce {
        local_nonce
    } else {
        nonce
    };

    let mut nonce_bytes = [0; 32];

    (nonce + U256::from(1)).to_big_endian(&mut nonce_bytes);

    std::fs::write(nonce_file, nonce_bytes)
        .map_err(|err| format!("Error writing to file in path {:?}: {err}", nonce_file))?;

    Ok(nonce)
}
