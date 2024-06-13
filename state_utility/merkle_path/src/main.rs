use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;
    let public_key_path = args.get(2).ok_or("Error: No public key file provided")?;
    process_input_json(
        rpc_url,
        public_key_path,
        "../eth_verifier/merkle_leaf.bin",
        "../eth_verifier/merkle_path.bin",
    )
}
