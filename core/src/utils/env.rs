use aligned_sdk::core::types::Chain;
extern crate dotenv;
use dotenv::dotenv;
use log::debug;

pub struct EnvironmentVariables {
    pub rpc_url: String,
    pub chain: Chain,
    pub batcher_addr: String,
    pub batcher_eth_addr: String,
    pub eth_rpc_url: String,
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

        // Default value is only valid for Anvil devnet execution.
        let load_var_or = |key: &str, default: &str| -> Result<String, String> {
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
        };

        let batcher_addr = load_var_or("BATCHER_ADDR", "ws://localhost:8080")?;
        let batcher_eth_addr = load_var_or(
            "BATCHER_ETH_ADDR",
            "0x7969c5eD335650692Bc04293B07F5BF2e7A673C0",
        )?;
        let eth_rpc_url = load_var_or("ETH_RPC_URL", "http://localhost:8545")?;

        Ok(EnvironmentVariables {
            rpc_url,
            chain,
            batcher_addr,
            batcher_eth_addr,
            eth_rpc_url,
        })
    }
}
