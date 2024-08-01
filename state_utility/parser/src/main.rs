use std::path::PathBuf;

use merkle_root_parser::query_and_parse_merkle_root;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;

    let mut merkle_root_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    merkle_root_path.push("../../merkle_root.pub");
    let merkle_root_path_str = merkle_root_path.to_str().ok_or(format!(
        "Error trying to parse output path {:?}",
        merkle_root_path
    ))?;

    query_and_parse_merkle_root(rpc_url, merkle_root_path_str)
}
