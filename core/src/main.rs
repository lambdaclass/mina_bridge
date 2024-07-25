use std::path::PathBuf;

use core::{aligned_polling_service, mina_polling_service};

#[tokio::main]
async fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;
    let output_path = args.get(2).ok_or("Error: No output path provided")?;

    let mut proof_path_buf = PathBuf::from(output_path);
    proof_path_buf.push("protocol_state.proof");

    let mut public_input_path_buf = PathBuf::from(output_path);
    public_input_path_buf.push("protocol_state.pub");

    let mina_proof = mina_polling_service::query_and_serialize(
        rpc_url,
        proof_path_buf.to_str().unwrap(),
        public_input_path_buf.to_str().unwrap(),
    )?;

    let _verification_data = aligned_polling_service::submit(&mina_proof).await?;

    Ok(())
}
