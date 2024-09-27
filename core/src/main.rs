use clap::{Parser, Subcommand};
use log::{error, info};
use mina_bridge_core::{
    aligned, eth, mina,
    proof::MinaProof,
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
        #[arg(short, long)]
        devnet: bool,
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
        /// Hash of the state to verify the account for
        state_hash: String,
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
        Command::SubmitState { devnet, save_proof } => {
            let (proof, pub_input) =
                mina::get_mina_proof_of_state(&rpc_url, &chain, &eth_rpc_url, devnet)
                    .await
                    .unwrap_or_else(|err| {
                        error!("{}", err);
                        process::exit(1);
                    });

            let verification_data = aligned::submit(
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

            eth::update_chain(
                verification_data,
                &pub_input,
                &chain,
                &eth_rpc_url,
                wallet,
                &batcher_eth_addr,
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
            state_hash,
        } => {
            let (proof, pub_input) =
                mina::get_mina_proof_of_account(&public_key, &state_hash, &rpc_url)
                    .await
                    .unwrap_or_else(|err| {
                        error!("{}", err);
                        process::exit(1);
                    });

            let verification_data = aligned::submit(
                MinaProof::Account((proof, pub_input.clone())),
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

            if let Err(err) = eth::validate_account(
                verification_data,
                &pub_input,
                &chain,
                &eth_rpc_url,
                &batcher_eth_addr,
            )
            .await
            {
                error!("Mina account {public_key} was not validated: {err}",);
            } else {
                info!("Mina account {public_key} was validated!");
            };
        }
    }

    if let Ok(elapsed) = now.elapsed() {
        info!("Time spent: {} s", elapsed.as_secs());
    }
}
