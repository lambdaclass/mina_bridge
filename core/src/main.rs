use clap::{Parser, Subcommand};
use log::{error, info};
use mina_bridge_core::{
    aligned_polling_service, mina_polling_service, smart_contract_utility,
    utils::{env::EnvironmentVariables, wallet::get_wallet},
};
use mina_p2p_messages::v2::StateHash;
use std::{process, time::SystemTime};

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
    #[arg(short, long)]
    save_proof: bool,
}

#[derive(Subcommand)]
enum Command {
    SubmitState,
    SubmitAccount {
        /// Write the proof into .proof and .pub files.
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
        Command::SubmitState => {
            let proof = mina_polling_service::get_mina_proof_of_state(
                &rpc_url,
                &proof_generator_addr,
                &chain,
                &eth_rpc_url,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            if cli.save_proof {
                std::fs::write(
                    "./protocol_state.pub",
                    proof.pub_input.as_ref().unwrap_or_else(|| {
                        error!("Tried to save public inputs to file but they're missing");
                        process::exit(1);
                    }),
                )
                .unwrap_or_else(|err| {
                    error!("{}", err);
                    process::exit(1);
                });
                std::fs::write("./protocol_state.proof", &proof.proof).unwrap_or_else(|err| {
                    error!("{}", err);
                    process::exit(1);
                });
            }

            let verification_data = aligned_polling_service::submit(
                &proof,
                &chain,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                wallet.clone(),
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            let pub_input = proof.pub_input.unwrap_or_else(|| {
                error!("Missing public inputs from Mina state proof");
                process::exit(1);
            });

            let verified_state_hash = smart_contract_utility::update_tip(
                verification_data,
                pub_input,
                &chain,
                &eth_rpc_url,
                wallet,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            info!(
                "Success! verified Mina state hash {} was stored in the bridge's smart contract",
                StateHash::from_fp(verified_state_hash)
            );
        }
        Command::SubmitAccount { public_key } => {
            let proof = mina_polling_service::get_mina_proof_of_account(
                &public_key,
                &rpc_url,
                &proof_generator_addr,
                &chain,
                &eth_rpc_url,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            if cli.save_proof {
                std::fs::write(
                    format!("./account_{public_key}.pub"),
                    proof.pub_input.as_ref().unwrap_or_else(|| {
                        error!("Tried to save public inputs to file but they're missing");
                        process::exit(1);
                    }),
                )
                .unwrap_or_else(|err| {
                    error!("{}", err);
                    process::exit(1);
                });
                std::fs::write(format!("./account_{public_key}.proof"), &proof.proof)
                    .unwrap_or_else(|err| {
                        error!("{}", err);
                        process::exit(1);
                    });
            }

            let verification_data = aligned_polling_service::submit(
                &proof,
                &chain,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                wallet.clone(),
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            let pub_input = proof.pub_input.unwrap_or_else(|| {
                error!("Missing public inputs from Mina account proof");
                process::exit(1);
            });

            smart_contract_utility::update_account(
                verification_data,
                pub_input,
                &chain,
                &eth_rpc_url,
                wallet,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            info!("Success! verified Mina account state was stored in the bridge's smart contract");
        }
    }

    if let Ok(elapsed) = now.elapsed() {
        info!("Time spent: {} s", elapsed.as_secs());
    }
}
