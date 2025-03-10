use aligned_sdk::core::types::Network;
use alloy::{
    network::EthereumWallet,
    signers::local::{LocalSigner, PrivateKeySigner},
};
use log::info;
use zeroize::Zeroizing;

use crate::utils::constants::ANVIL_PRIVATE_KEY;

pub fn get_wallet(
    network: &Network,
    keystore_path: Option<&str>,
    private_key: Option<&str>,
) -> Result<EthereumWallet, String> {
    if keystore_path.is_some() && private_key.is_some() {
        return Err(
            "Both keystore and private key env. variables are defined. Choose only one."
                .to_string(),
        );
    }

    if matches!(network, Network::Holesky) {
        if let Some(keystore_path) = keystore_path {
            info!("Using keystore for Holesky wallet");
            let password = Zeroizing::new(
                rpassword::prompt_password("Please enter your keystore password:")
                    .map_err(|err| err.to_string())?,
            );
            let signer = LocalSigner::decrypt_keystore(keystore_path, password)
                .map_err(|err| err.to_string())?;
            Ok(EthereumWallet::new(signer))
        } else if let Some(private_key) = private_key {
            info!("Using private key for Holesky wallet");
            let signer: PrivateKeySigner = private_key
                .parse()
                .map_err(|_| "Failed to get Anvil signer".to_string())?;
            Ok(EthereumWallet::new(signer))
        } else {
            return Err(
                "Holesky chain was selected but couldn't find KEYSTORE_PATH or PRIVATE_KEY."
                    .to_string(),
            );
        }
    } else {
        info!("Using Anvil wallet 9");
        let signer: PrivateKeySigner = ANVIL_PRIVATE_KEY
            .parse()
            .map_err(|_| "Failed to get Anvil signer".to_string())?;
        Ok(EthereumWallet::new(signer))
    }
}
