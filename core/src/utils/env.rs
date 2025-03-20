use aligned_sdk::core::types::Network;
extern crate dotenv;
use dotenv::dotenv;
use log::debug;

use super::constants::{
    ANVIL_BATCHER_ADDR, ANVIL_BATCHER_ETH_ADDR, ANVIL_ETH_RPC_URL, PROOF_GENERATOR_ADDR,
};

/// Struct that is created by reading environment variables or, for some fields, from defined constants if the
/// corresponding environment variable is not defined.
///
/// - `rpc_url`: Mina node RPC URL to get the Mina state
/// - `network`: Enum variant to specify the Ethereum network to update the Mina state
/// - `state_settlement_addr`: Address of the Mina State Settlement Example Contract
/// - `account_validation_addr`: Address of the Mina Account Validation Example Contract
/// - `batcher_addr`: Address of the Aligned Batcher Service
/// - `batcher_eth_addr`: Address of the Aligned Batcher Payment Service
/// - `eth_rpc_url`: Ethereum node RPC URL to send the transaction to update the Mina state
/// - `proof_generator_addr`: Address of the Aligned Proof Generator
/// - `keystore_path`: Path to the keystore used to sign Ethereum transactions.
///   `None` if `private_key` is defined.
/// - `private_key`: Private key of the Ethereum wallet used to sign Ethereum transactions.
///   `None` if `keystore_path` is defined.
pub struct EnvironmentVariables {
    pub rpc_url: String,
    pub network: Network,
    pub state_settlement_addr: Option<String>,
    pub account_validation_addr: Option<String>,
    pub batcher_addr: String,
    pub batcher_eth_addr: String,
    pub eth_rpc_url: String,
    pub proof_generator_addr: String,
    pub keystore_path: Option<String>,
    pub private_key: Option<String>,
}

fn load_var_or(key: &str, default: &str, network: &Network) -> Result<String, String> {
    // Default value is only valid for Anvil devnet setup.
    match std::env::var(key) {
        Ok(value) => Ok(value),
        Err(_) if matches!(network, Network::Devnet) => {
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
    /// Creates the `EnvironmentVariables` struct from environment variables or, for some fields, from defined
    /// constants if the corresponding environment variable is not defined.
    ///
    /// Returns `Err` if:
    ///
    /// - `MINA_RPC_URL` or `ETH_CHAIN` environemnt variables are not defined
    /// - `ETH_CHAIN` is not set to a valid Ethereum network (`"devnet"` or `"holesky"`)
    /// - Both `KEYSTORE_PATH` and `PRIVATE_KEY` are set
    pub fn new() -> Result<EnvironmentVariables, String> {
        dotenv().map_err(|err| format!("Couldn't load .env file: {}", err))?;

        let rpc_url = std::env::var("MINA_RPC_URL")
            .map_err(|err| format!("Couldn't get MINA_RPC_URL env. variable: {err}"))?;
        let network = match std::env::var("ETH_CHAIN")
            .map_err(|err| format!("Couldn't get ETH_CHAIN env. variable: {err}"))?
            .as_str()
        {
            "devnet" => {
                debug!("Selected Anvil devnet chain.");
                Network::Devnet
            }
            "holesky" => {
                debug!("Selected Holesky chain.");
                Network::Holesky
            }
            _ => return Err(
                "Unrecognized chain, possible values for ETH_CHAIN are \"devnet\" and \"holesky\"."
                    .to_owned(),
            ),
        };

        let state_settlement_addr = std::env::var("STATE_SETTLEMENT_ETH_ADDR").ok();
        let account_validation_addr = std::env::var("ACCOUNT_VALIDATION_ETH_ADDR").ok();

        let batcher_addr = load_var_or("BATCHER_ADDR", ANVIL_BATCHER_ADDR, &network)?;
        let batcher_eth_addr = load_var_or("BATCHER_ETH_ADDR", ANVIL_BATCHER_ETH_ADDR, &network)?;
        let eth_rpc_url = load_var_or("ETH_RPC_URL", ANVIL_ETH_RPC_URL, &network)?;
        let proof_generator_addr =
            load_var_or("PROOF_GENERATOR_ADDR", PROOF_GENERATOR_ADDR, &network)?;

        let keystore_path = std::env::var("KEYSTORE_PATH").ok();
        let private_key = std::env::var("PRIVATE_KEY").ok();

        if keystore_path.is_some() && private_key.is_some() {
            return Err(
                "Both keystore and private key env. variables are defined. Choose only one."
                    .to_string(),
            );
        }

        Ok(EnvironmentVariables {
            rpc_url,
            network,
            state_settlement_addr,
            account_validation_addr,
            batcher_addr,
            batcher_eth_addr,
            eth_rpc_url,
            proof_generator_addr,
            keystore_path,
            private_key,
        })
    }
}
