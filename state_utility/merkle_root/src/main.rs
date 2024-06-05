use merkle_path::process_merkle_root;

fn main() -> Result<(), String> {
    let mut args = std::env::args();

    let merkle_root_path = args.nth(1).ok_or("Error: No merkle root file provided")?;
    process_merkle_root(&merkle_root_path, "./merkle_root.bin")
}
