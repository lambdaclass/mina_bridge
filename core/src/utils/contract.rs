use aligned_sdk::core::types::Chain;

use super::constants::{
    ALIGNED_SM_DEVNET_ETH_ADDR, BRIDGE_ACCOUNT_DEVNET_ETH_ADDR, BRIDGE_DEVNET_ETH_ADDR,
};

pub fn get_bridge_contract_addr(chain: &Chain) -> Result<String, String> {
    match chain {
        Chain::Devnet => Ok(BRIDGE_DEVNET_ETH_ADDR.to_owned()),
        Chain::Holesky => std::env::var("BRIDGE_HOLESKY_ETH_ADDR")
            .map_err(|err| format!("Error getting Bridge contract address: {err}")),
        _ => Err("Unimplemented Ethereum contract on selected chain".to_owned()),
    }
}

pub fn get_account_validation_contract_addr(chain: &Chain) -> Result<String, String> {
    match chain {
        Chain::Devnet => Ok(BRIDGE_ACCOUNT_DEVNET_ETH_ADDR.to_owned()),
        Chain::Holesky => std::env::var("BRIDGE_ACCOUNT_HOLESKY_ETH_ADDR")
            .map_err(|err| format!("Error getting Account validation contract address: {err}")),
        _ => Err("Unimplemented Ethereum contract on selected chain".to_owned()),
    }
}

pub fn get_aligned_sm_contract_addr(chain: &Chain) -> Result<String, String> {
    match chain {
        Chain::Devnet => Ok(ALIGNED_SM_DEVNET_ETH_ADDR.to_owned()),
        Chain::Holesky => std::env::var("ALIGNED_SM_HOLESKY_ETH_ADDR")
            .map_err(|err| format!("Error getting Aligned SM contract address: {err}")),
        _ => Err("Unimplemented Ethereum contract on selected chain".to_owned()),
    }
}
