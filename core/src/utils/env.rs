use aligned_sdk::core::types::Chain;
extern crate dotenv;
use dotenv::dotenv;
use log::debug;

use super::constants::{
    ANVIL_BATCHER_ADDR, ANVIL_BATCHER_ETH_ADDR, ANVIL_ETH_RPC_URL, ANVIL_PROOF_GENERATOR_ADDR,
};

pub struct EnvironmentVariables {
    pub rpc_url: String,
    pub chain: Chain,
    pub batcher_addr: String,
    pub batcher_eth_addr: String,
    pub eth_rpc_url: String,
    pub proof_generator_addr: String,
    pub keystore_path: Option<String>,
    pub private_key: Option<String>,
    pub save_proof: bool,
}

fn load_var_or(key: &str, default: &str, chain: &Chain) -> Result<String, String> {
    // Default value is only valid for Anvil devnet setup.
    match std::env::var(key) {
        Ok(value) => Ok(value),
        Err(_) if matches!(chain, Chain::Devnet) => {
            debug!("Using default {} for devnet: {}", key, default);
            Ok(default.to_string())
        }
        Err(err) => Err(format!(
            "Chain selected is not Devnet but couldn't read {}: {}",
            key, err
        )),
    }
}

impl EnvironmentVariables {
    pub fn new() -> Result<EnvironmentVariables, String> {
        dotenv().map_err(|err| format!("Couldn't load .env file: {}", err))?;

        let rpc_url = std::env::var("MINA_RPC_URL")
            .map_err(|err| format!("Couldn't get MINA_RPC_URL env. variable: {err}"))?;
        let chain = match std::env::var("ETH_CHAIN")
            .map_err(|err| format!("Couldn't get ETH_CHAIN env. variable: {err}"))?
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

        let batcher_addr = load_var_or("BATCHER_ADDR", ANVIL_BATCHER_ADDR, &chain)?;
        let batcher_eth_addr = load_var_or("BATCHER_ETH_ADDR", ANVIL_BATCHER_ETH_ADDR, &chain)?;
        let eth_rpc_url = load_var_or("ETH_RPC_URL", ANVIL_ETH_RPC_URL, &chain)?;
        let proof_generator_addr =
            load_var_or("PROOF_GENERATOR_ADDR", ANVIL_PROOF_GENERATOR_ADDR, &chain)?;

        let keystore_path = std::env::var("KEYSTORE_PATH").ok();
        let private_key = std::env::var("PRIVATE_KEY").ok();

        if keystore_path.is_some() && private_key.is_some() {
            return Err(
                "Both keystore and private key env. variables are defined. Choose only one."
                    .to_string(),
            );
        }

        let save_proof =
            matches!(std::env::var("SAVE_PROOF"), Ok(value) if value.to_lowercase() == "true");

        Ok(EnvironmentVariables {
            rpc_url,
            chain,
            batcher_addr,
            batcher_eth_addr,
            eth_rpc_url,
            proof_generator_addr,
            keystore_path,
            private_key,
            save_proof,
        })
    }
}
