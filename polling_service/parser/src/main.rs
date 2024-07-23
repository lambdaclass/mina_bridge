use std::path::PathBuf;

use parser::parse_public_input;

pub fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;
    let output_path = args.get(2).ok_or("Error: No output path provided")?;

    let mut proof_path_buf = PathBuf::from(output_path);
    proof_path_buf.push("protocol_state.proof");

    let mut public_input_path_buf = PathBuf::from(output_path);
    public_input_path_buf.push("protocol_state.pub");

    parse_public_input(
        rpc_url,
        proof_path_buf.to_str().unwrap(),
        public_input_path_buf.to_str().unwrap(),
    )
}
