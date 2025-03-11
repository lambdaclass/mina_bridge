use std::{process, str::FromStr};

use aligned_sdk::{
    core::types::{
        AlignedVerificationData, FeeEstimationType, Network, ProvingSystemId, VerificationData,
    },
    sdk::estimate_fee,
};

use ethers::{
    core::k256::ecdsa::SigningKey,
    signers::Wallet,
    types::{Address, U256},
};
use futures::TryFutureExt;
use log::{error, info};

use crate::proof::MinaProof;

/// Submits a Mina Proof to Aligned's batcher and waits until the batch is verified.
#[allow(clippy::too_many_arguments)]
pub async fn submit(
    proof: MinaProof,
    network: &Network,
    proof_generator_addr: &str,
    _batcher_addr: &str,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
    save_proof: bool,
) -> Result<AlignedVerificationData, String> {
    let (proof, pub_input, proving_system, proof_name, file_name) = match proof {
        MinaProof::State((proof, pub_input)) => {
            let proof = bincode::serialize(&proof)
                .map_err(|err| format!("Failed to serialize state proof: {err}"))?;
            let pub_input = bincode::serialize(&pub_input)
                .map_err(|err| format!("Failed to serialize public inputs: {err}"))?;
            (
                proof,
                pub_input,
                ProvingSystemId::Mina,
                "Mina Proof of State",
                "mina_state",
            )
        }
        MinaProof::Account((proof, pub_input)) => {
            let proof = bincode::serialize(&proof)
                .map_err(|err| format!("Failed to serialize state proof: {err}"))?;
            let pub_input = bincode::serialize(&pub_input)
                .map_err(|err| format!("Failed to serialize public inputs: {err}"))?;
            (
                proof,
                pub_input,
                ProvingSystemId::MinaAccount,
                "Mina Proof of Account",
                "mina_account",
            )
        }
    };

    if save_proof {
        std::fs::write(format!("./{file_name}.pub"), &pub_input).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
        std::fs::write(format!("./{file_name}.proof"), &proof).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    }

    let proof_generator_addr =
        Address::from_str(proof_generator_addr).map_err(|err| err.to_string())?;

    let verification_data = VerificationData {
        proving_system,
        proof,
        pub_input: Some(pub_input),
        // Use this instead of `None` to force Aligned to include the commitment to the proving system ID (valid for Aligned 0.7.0)
        verification_key: Some(vec![]),
        vm_program_code: None,
        proof_generator_addr,
    };

    let max_fee = estimate_fee(eth_rpc_url, FeeEstimationType::Instant)
        .map_err(|err| err.to_string())
        .await?;

    info!("Max fee: {max_fee} gas");

    info!("Submitting {proof_name} into Aligned and waiting for the batch to be verified...");
    aligned_sdk::sdk::submit_and_wait_verification(
        eth_rpc_url,
        network.to_owned(),
        &verification_data,
        max_fee,
        wallet,
        U256::from(0),
    )
    .await
    .map_err(|e| e.to_string())
}
