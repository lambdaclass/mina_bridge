use aligned_sdk::{
    core::types::{AlignedVerificationData, Chain, VerificationData},
    sdk::{get_next_nonce, submit_and_wait},
};
use ethers::{
    core::k256::ecdsa::SigningKey,
    signers::{Signer, Wallet},
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
    let nonce = get_next_nonce(eth_rpc_url, wallet.address(), batcher_eth_addr)
        .await
        .map_err(|err| err.to_string())?;

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
