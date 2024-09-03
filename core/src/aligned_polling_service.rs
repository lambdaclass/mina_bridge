use std::{path::PathBuf, process, str::FromStr};

use aligned_sdk::{
    core::types::{AlignedVerificationData, Chain, ProvingSystemId, VerificationData},
    sdk::{get_next_nonce, submit_and_wait},
};
use ethers::{
    core::k256::ecdsa::SigningKey,
    signers::{Signer, Wallet},
    types::{Address, U256},
};
use log::{error, info};

use crate::proof::state_proof::{MinaStateProof, MinaStatePubInputs};

/// Submits a Mina state proof to Aligned's batcher and waits until the batch is verified.
#[allow(clippy::too_many_arguments)]
pub async fn submit_state_proof(
    proof: &MinaStateProof,
    pub_input: &MinaStatePubInputs,
    chain: &Chain,
    proof_generator_addr: &str,
    batcher_addr: &str,
    batcher_eth_addr: &str,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
    save_proof: bool,
) -> Result<AlignedVerificationData, String> {
    let proof = bincode::serialize(proof)
        .map_err(|err| format!("Failed to serialize state proof: {err}"))?;
    let pub_input = bincode::serialize(pub_input)
        .map_err(|err| format!("Failed to serialize public inputs: {err}"))?;

    if save_proof {
        std::fs::write("./protocol_state.pub", &pub_input).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
        std::fs::write("./protocol_state.proof", &proof).unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    }

    let proof_generator_addr =
        Address::from_str(proof_generator_addr).map_err(|err| err.to_string())?;

    let verification_data = VerificationData {
        proving_system: ProvingSystemId::Mina,
        proof,
        pub_input: Some(pub_input),
        verification_key: None,
        vm_program_code: None,
        proof_generator_addr,
    };

    let wallet_address = wallet.address();
    let nonce = get_nonce(eth_rpc_url, wallet_address, batcher_eth_addr).await?;

    info!(
        "Submitting Mina Proof of State into Aligned and waiting for the batch to be verified..."
    );
    submit_with_nonce(
        batcher_addr,
        eth_rpc_url,
        chain,
        &verification_data,
        wallet,
        nonce,
    )
    .await
    .or_else(|err| {
        let nonce_file = &get_nonce_file(wallet_address);
        std::fs::remove_file(nonce_file)
            .map_err(|err| format!("Error trying to remove nonce file: {err}"))?;

        Err(err)
    })
}

/// Submits a Mina (state or account) proof to Aligned's batcher and waits until the batch is verified.
pub async fn submit(
    mina_proof: &VerificationData,
    chain: &Chain,
    batcher_addr: &str,
    batcher_eth_addr: &str,
    eth_rpc_url: &str,
    wallet: Wallet<SigningKey>,
) -> Result<AlignedVerificationData, String> {
    let wallet_address = wallet.address();
    let nonce = get_nonce(eth_rpc_url, wallet_address, batcher_eth_addr).await?;

    let proof_type = match mina_proof.proving_system {
        ProvingSystemId::Mina => "Mina Proof of State",
        ProvingSystemId::MinaAccount => "Mina Proof of Account",
        _ => return Err("Tried to submit a non Mina proof".to_string()),
    };

    info!("Submitting {proof_type} into Aligned and waiting for the batch to be verified...");
    submit_with_nonce(batcher_addr, eth_rpc_url, chain, mina_proof, wallet, nonce)
        .await
        .or_else(|err| {
            let nonce_file = &get_nonce_file(wallet_address);
            std::fs::remove_file(nonce_file)
                .map_err(|err| format!("Error trying to remove nonce file: {err}"))?;

            Err(err)
        })
}

async fn submit_with_nonce(
    batcher_addr: &str,
    eth_rpc_url: &str,
    chain: &Chain,
    mina_proof: &VerificationData,
    wallet: Wallet<SigningKey>,
    nonce: U256,
) -> Result<AlignedVerificationData, String> {
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

async fn get_nonce(
    eth_rpc_url: &str,
    address: Address,
    batcher_eth_addr: &str,
) -> Result<U256, String> {
    let nonce = get_next_nonce(eth_rpc_url, address, batcher_eth_addr)
        .await
        .map_err(|err| err.to_string())?;

    let nonce_file = &get_nonce_file(address);

    let local_nonce = std::fs::read(nonce_file).unwrap_or(vec![0u8; 32]);
    let local_nonce = U256::from_big_endian(local_nonce.as_slice());

    let nonce = if local_nonce > nonce {
        local_nonce
    } else {
        nonce
    };

    let mut nonce_bytes = [0; 32];

    (nonce + U256::from(1)).to_big_endian(&mut nonce_bytes);

    std::fs::write(nonce_file, nonce_bytes)
        .map_err(|err| format!("Error writing to file in path {:?}: {err}", nonce_file))?;

    Ok(nonce)
}

fn get_nonce_file(address: Address) -> PathBuf {
    PathBuf::from(format!("nonce_{:?}.bin", address))
}
