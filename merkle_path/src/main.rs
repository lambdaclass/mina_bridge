use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let mut args = std::env::args();

    let public_key_path = args.nth(1).ok_or("Error: No public key file provided")?;
    let merkle_root_path = args.nth(2).ok_or("Error: No merkle root file provided")?;
    process_input_json(&public_key_path, &merkle_root_path, "./out.bin")
}
