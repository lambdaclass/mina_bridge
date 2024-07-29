use std::str::FromStr;

use aligned_sdk::{
    core::types::{AlignedVerificationData, Chain, VerificationData},
    sdk::{get_next_nonce, submit_and_wait},
};
use ethers::signers::{LocalWallet, Signer, Wallet};
use log::info;

use crate::constants::ANVIL_PRIVATE_KEY;

/// Submits a Mina proof to Aligned's batcher and waits until the batch is verified.
pub async fn submit(
    mina_proof: &VerificationData,
    chain: &Chain,
    batcher_addr: &str,
    batcher_eth_addr: &str,
    eth_rpc_url: &str,
) -> Result<AlignedVerificationData, String> {
    let wallet = if matches!(chain, Chain::Holesky) {
        if let Ok(keystore_path) = std::env::var("KEYSTORE_PATH") {
            info!("Using keystore for Holesky wallet");
            let password = rpassword::prompt_password("Please enter your keystore password:")
                .map_err(|err| err.to_string())?;
            Wallet::decrypt_keystore(keystore_path, password).map_err(|err| err.to_string())?
        } else if let Ok(private_key) = std::env::var("PRIVATE_KEY") {
            info!("Using private key for Holesky wallet");
            private_key
                .parse::<LocalWallet>()
                .map_err(|err| err.to_string())?
        } else {
            return Err(
                "Holesky chain was selected but couldn't find KEYSTORE_PATH or PRIVATE_KEY."
                    .to_string(),
            );
        }
    } else {
        info!("Using Anvil wallet");
        LocalWallet::from_str(ANVIL_PRIVATE_KEY).expect("failed to create wallet")
    };
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
