extern crate dotenv;

use core::{aligned_polling_service, mina_polling_service};
use log::{error, info};
use std::path::PathBuf;

#[tokio::main]
async fn main() -> Result<(), String> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    info!("Mina bridge starts");

    let dotenv_path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(".env");
    if let Err(err) = dotenv::from_path(dotenv_path) {
        error!("Couldn't load .env file: {}", err);
    }

    let rpc_url = std::env::var("MINA_RPC_URL").expect("couldn't read MINA_RPC_URL env. variable.");
    let output_path = "."; // TODO(xqft): embellish this

    let mut proof_path_buf = PathBuf::from(output_path);
    proof_path_buf.push("protocol_state.proof");

    let mut public_input_path_buf = PathBuf::from(output_path);
    public_input_path_buf.push("protocol_state.pub");

    // TODO(xqft): add logging to mina_polling_service
    info!("Executing Mina polling service");
    let mina_proof = mina_polling_service::query_and_serialize(
        &rpc_url,
        proof_path_buf.to_str().unwrap(),
        public_input_path_buf.to_str().unwrap(),
    )
    .inspect_err(|err| error!("{}", err))?;

    info!("Executing Aligned polling service");
    let _verification_data = aligned_polling_service::submit(&mina_proof)
        .await
        .inspect_err(|err| error!("{}", err))?;

    // smart_contract_utility::update(verification_data);

    Ok(())
}
