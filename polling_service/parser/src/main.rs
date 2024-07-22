use std::path::PathBuf;

use parser::parse_public_input;

pub fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;

    let mut state_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    state_path.push("../../protocol_state.pub");
    parse_public_input(&rpc_url, state_path.to_str().unwrap())
}
