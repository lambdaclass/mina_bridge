use merkle_root::process_merkle_root;

fn main() -> Result<(), String> {
    let mut args = std::env::args();

    let merkle_root_in_path = args.nth(1).ok_or("Error: No merkle root file provided")?;
    let merkle_root_out_path = args.nth(2).ok_or("Error: No merkle root out path")?;
    process_merkle_root(&merkle_root_in_path, &merkle_root_out_path)
}
