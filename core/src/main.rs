extern crate dotenv;

use core::{aligned_polling_service, mina_polling_service};
use dotenv::dotenv;
use std::path::PathBuf;

#[tokio::main]
async fn main() -> Result<(), String> {
    dotenv().ok();

    let rpc_url = std::env::var("MINA_RPC_URL").expect("couldn't read MINA_RPC_URL env. variable.");
    let output_path = ".";

    let mut proof_path_buf = PathBuf::from(output_path);
    proof_path_buf.push("protocol_state.proof");

    let mut public_input_path_buf = PathBuf::from(output_path);
    public_input_path_buf.push("protocol_state.pub");

    let mina_proof = mina_polling_service::query_and_serialize(
        &rpc_url,
        proof_path_buf.to_str().unwrap(),
        public_input_path_buf.to_str().unwrap(),
    )?;

    let _verification_data = aligned_polling_service::submit(&mina_proof).await?;

    Ok(())
}
