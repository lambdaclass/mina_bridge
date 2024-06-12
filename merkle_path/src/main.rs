use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let public_key_path = args.get(1).ok_or("Error: No public key file provided")?;
    process_input_json(
        public_key_path,
        "../eth_verifier/merkle_leaf.bin",
        "../eth_verifier/merkle_path.bin",
    )
}
