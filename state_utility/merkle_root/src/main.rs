use merkle_root::process_merkle_root;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let merkle_root_in_path = args.get(1).ok_or("Error: No merkle root file provided")?;
    let merkle_root_out_path = args.get(2).ok_or("Error: No merkle root out path")?;
    process_merkle_root(merkle_root_in_path, merkle_root_out_path)
}
