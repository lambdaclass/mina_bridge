use clap::{Parser, Subcommand};
use log::{error, info};
use mina_bridge_core::{
    aligned_polling_service, mina_polling_service,
    proof::MinaProof,
    smart_contract_utility,
    utils::{env::EnvironmentVariables, wallet::get_wallet},
};
use std::{process, time::SystemTime};

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    SubmitState {
        /// Write the proof into .proof and .pub files
        #[arg(short, long)]
        save_proof: bool,
    },
    SubmitAccount {
        /// Write the proof into .proof and .pub files
        #[arg(short, long)]
        save_proof: bool,
        /// Public key string of the account to verify
        public_key: String,
    },
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let now = SystemTime::now();
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let EnvironmentVariables {
        rpc_url,
        chain,
        batcher_addr,
        batcher_eth_addr,
        eth_rpc_url,
        proof_generator_addr,
        keystore_path,
        private_key,
    } = EnvironmentVariables::new().unwrap_or_else(|err| {
        error!("{}", err);
        process::exit(1);
    });

    let wallet = get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });

    match cli.command {
        Command::SubmitState { save_proof } => {
            let (proof, pub_input) =
                mina_polling_service::get_mina_proof_of_state(&rpc_url, &chain, &eth_rpc_url)
                    .await
                    .unwrap_or_else(|err| {
                        error!("{}", err);
                        process::exit(1);
                    });

            let verification_data = aligned_polling_service::submit(
                MinaProof::State((proof, pub_input.clone())),
                &chain,
                &proof_generator_addr,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                wallet.clone(),
                save_proof,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            smart_contract_utility::update_chain(
                verification_data,
                &pub_input,
                &chain,
                &eth_rpc_url,
                wallet,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });
        }
        Command::SubmitAccount {
            save_proof,
            public_key,
        } => {
            let (proof, pub_input) = mina_polling_service::get_mina_proof_of_account(
                &public_key,
                &rpc_url,
                &chain,
                &eth_rpc_url,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            // Use for calling the smart contract to check if the account was verified on Aligned.
            let serialized_pub_input = bincode::serialize(&pub_input).unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            let verification_data = aligned_polling_service::submit(
                MinaProof::Account((proof, pub_input)),
                &chain,
                &proof_generator_addr,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                wallet.clone(),
                save_proof,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            let is_account_verified = smart_contract_utility::is_account_verified(
                verification_data,
                serialized_pub_input,
                &chain,
                &eth_rpc_url,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            info!(
                "Mina account {public_key} was {} on Aligned!",
                if is_account_verified {
                    "verified"
                } else {
                    "not verified"
                }
            );
        }
    }

    if let Ok(elapsed) = now.elapsed() {
        info!("Time spent: {} s", elapsed.as_secs());
    }
}
