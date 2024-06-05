use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let public_key_path = args.get(1).ok_or("Error: No public key file provided")?;
    let merkle_root_path = args.get(2).ok_or("Error: No merkle root file provided")?;
    process_input_json(public_key_path, merkle_root_path, "./out.bin")
}
