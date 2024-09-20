use aligned_sdk::core::types::Chain;
use alloy::{primitives::Address, providers::ProviderBuilder, sol_types::sol};
use clap::{Parser, Subcommand};
use log::{error, info};
use mina_bridge_core::{
    sdk::{get_bridged_chain_tip_state_hash, update_bridge_chain, validate_account},
    utils::{
        constants::{
            BRIDGE_ACCOUNT_DEVNET_ETH_ADDR, BRIDGE_DEVNET_ETH_ADDR, BRIDGE_HOLESKY_ETH_ADDR,
        },
        env::EnvironmentVariables,
        wallet, wallet_alloy,
    },
};
use std::{process, str::FromStr};

const MINA_ZKAPP_ADDRESS: &str = "B62qmpq1JBejZYDQrZwASPRM5oLXW346WoXgbApVf5HJZXMWFPWFPuA";

sol!(
    #[allow(clippy::too_many_arguments)]
    #[sol(rpc)]
    SudokuValidity,
    "abi/SudokuValidity.json"
);

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    DeployContract,
    ValidateSolution,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
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

    let wallet = wallet::get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
        .unwrap_or_else(|err| {
            error!("{}", err);
            process::exit(1);
        });
    let wallet_alloy =
        wallet_alloy::get_wallet(&chain, keystore_path.as_deref(), private_key.as_deref())
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

    match cli.command {
        Command::DeployContract => {
            let provider = ProviderBuilder::new()
                .with_recommended_fillers()
                .wallet(wallet_alloy)
                .on_http(
                    reqwest::Url::parse(&eth_rpc_url)
                        .map_err(|err| err.to_string())
                        .unwrap(),
                );

            // TODO(xqft): we might as well use the Chain type from Alloy, it isn't right to add
            // aligned-sdk as a dependency only for this type.
            let state_settlement_addr = match chain {
                Chain::Devnet => BRIDGE_DEVNET_ETH_ADDR,
                Chain::Holesky => BRIDGE_HOLESKY_ETH_ADDR,
                _ => todo!(),
            };

            let account_validation_addr = match chain {
                Chain::Devnet => BRIDGE_ACCOUNT_DEVNET_ETH_ADDR,
                _ => todo!(),
            };

            let contract = SudokuValidity::deploy(
                &provider,
                Address::from_str(state_settlement_addr).unwrap(),
                Address::from_str(account_validation_addr).unwrap(),
            )
            .await
            .map_err(|err| err.to_string())
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });

            info!(
                "SudokuValidity contract successfuly deployed with address {}",
                contract.address()
            );
        }
        Command::ValidateSolution => {
            // We could check if the specific block containing the tx is already verified, before
            // updating the bridge's chain.
            // let is_state_verified = is_state_verified(&state_hash, &chain, &eth_rpc_url)
            //     .await
            //     .unwrap_or_else(|err| {
            //         error!("{}", err);
            //         process::exit(1);
            //     });

            // if !is_state_verified {
            //     info!("State that includes the zkApp tx isn't verified. Bridging latest chain...");
            let state_verification_result = update_bridge_chain(
                &rpc_url,
                &chain,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                &proof_generator_addr,
                wallet.clone(),
                false,
            )
            .await;

            match state_verification_result {
                Err(err) if err == "Latest chain is already verified" => {
                    info!("Bridge chain is up to date, won't verify new states.")
                }
                Err(err) => {
                    error!("{}", err);
                    process::exit(1);
                }
                _ => {}
            }
            // }

            let tip_state_hash = get_bridged_chain_tip_state_hash(&chain, &eth_rpc_url)
                .await
                .unwrap_or_else(|err| {
                    error!("{}", err);
                    process::exit(1);
                });

            validate_account(
                MINA_ZKAPP_ADDRESS,
                &tip_state_hash,
                &rpc_url,
                &chain,
                &batcher_addr,
                &batcher_eth_addr,
                &eth_rpc_url,
                &proof_generator_addr,
                wallet,
                false,
            )
            .await
            .unwrap_or_else(|err| {
                error!("{}", err);
                process::exit(1);
            });
        }
    }
}
