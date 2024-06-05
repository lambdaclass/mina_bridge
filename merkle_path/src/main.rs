use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let mut args = std::env::args();

    let public_key_path = args.nth(1).ok_or("Error: No public key file provided")?;
    process_input_json(&public_key_path, "./leaf_hash.bin", "./merkle_path.bin")
}
