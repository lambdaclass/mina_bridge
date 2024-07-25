use aligned_sdk::core::types::{AlignedVerificationData, Chain};

// abigen MinaBridgeContract

pub async fn update(
    verification_data: &AlignedVerificationData,
    chain: Chain,
) -> Result<(), String> {
    // TODO(xqft): contract address
    let contract_address = match chain {
        Chain::Devnet => "0x0",
        _ => unimplemented!(),
    };

    // let mina_bridge_contract;
    // mina_bridge_contract.update(verification_data)

    Ok(())
}
