use std::str::FromStr;

use aligned_sdk::{
    core::types::{AlignedVerificationData, Chain, VerificationData},
    sdk::{get_next_nonce, submit_and_wait},
};
use ethers::signers::{LocalWallet, Signer, Wallet};

const ANVIL_PRIVATE_KEY: &str = "2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"; // Anvil address 9

pub async fn submit(mina_proof: &VerificationData) -> Result<AlignedVerificationData, String> {
    let batcher_addr = if let Ok(batcher_addr) = std::env::var("BATCHER_ADDR") {
        batcher_addr
    } else {
        "0x7969c5eD335650692Bc04293B07F5BF2e7A673C0".to_string()
    };
    let eth_rpc_url = if let Ok(eth_rpc_url) = std::env::var("ETH_RPC_URL") {
        eth_rpc_url
    } else {
        "http://localhost:8545".to_string()
    };
    let chain =
        match std::env::var("ETH_CHAIN")
            .expect("couldn't get ETH_CHAIN environment variable.")
            .as_str()
        {
            "devnet" => Chain::Devnet,
            "holesky" => Chain::Holesky,
            _ => return Err(
                "Unrecognized chain, possible values for ETH_CHAIN are \"devnet\" and \"holesky\"."
                    .to_owned(),
            ),
        };
    let wallet = if matches!(chain, Chain::Holesky) {
        if let Ok(keystore_path) = std::env::var("KEYSTORE_PATH") {
            let password = rpassword::prompt_password("Please enter your keystore password:")
                .map_err(|err| err.to_string())?;
            Wallet::decrypt_keystore(keystore_path, password).map_err(|err| err.to_string())?
        } else if let Ok(private_key) = std::env::var("PRIVATE_KEY") {
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
        LocalWallet::from_str(ANVIL_PRIVATE_KEY).expect("failed to create wallet")
    };
    let nonce = get_next_nonce(&eth_rpc_url, wallet.address(), &batcher_addr)
        .await
        .map_err(|err| err.to_string())?;

    let aligned_verification_data = submit_and_wait(
        &batcher_addr,
        &eth_rpc_url,
        chain,
        mina_proof,
        wallet,
        nonce,
    )
    .await
    .map_err(|err| err.to_string())?;

    if let Some(aligned_verification_data) = aligned_verification_data {
        Ok(aligned_verification_data)
    } else {
        Err("Verification data was not returned when submitting the proof, possibly because the connection was closed sooner than expected.".to_string())
    }
}
