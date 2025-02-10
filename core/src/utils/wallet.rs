use std::str::FromStr;

use aligned_sdk::core::types::Network;
use ethers::{
    prelude::k256::ecdsa::SigningKey,
    signers::{LocalWallet, Wallet, Signer},
};

use log::info;

use crate::utils::constants::{ANVIL_CHAIN_ID, ANVIL_PRIVATE_KEY, HOLESKY_CHAIN_ID};

pub fn get_wallet(
    network: &Network,
    keystore_path: Option<&str>,
    private_key: Option<&str>,
) -> Result<Wallet<SigningKey>, String> {
    if keystore_path.is_some() && private_key.is_some() {
        return Err(
            "Both keystore and private key env. variables are defined. Choose only one."
                .to_string(),
        );
    }

    if matches!(network, Network::Holesky) {
        if let Some(keystore_path) = keystore_path {
            info!("Using keystore for Holesky wallet");
            let password = rpassword::prompt_password("Please enter your keystore password:")
                .map_err(|err| err.to_string())?;
            Wallet::decrypt_keystore(keystore_path, password).map_err(|err| err.to_string())
        } else if let Some(private_key) = private_key {
            info!("Using private key for Holesky wallet");
            let wallet = private_key
                .parse::<LocalWallet>()
                .map_err(|err| err.to_string())?;

            Ok(wallet.with_chain_id(HOLESKY_CHAIN_ID))
        } else {
            return Err(
                "Holesky chain was selected but couldn't find KEYSTORE_PATH or PRIVATE_KEY."
                    .to_string(),
            );
        }
    } else {
        info!("Using Anvil wallet 9");
        let wallet = LocalWallet::from_str(ANVIL_PRIVATE_KEY)
            .map_err(|err| format!("Failed to create Anvil wallet: {}", err))?;

        Ok(wallet.with_chain_id(ANVIL_CHAIN_ID))
    }
}
