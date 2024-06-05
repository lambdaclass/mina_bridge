use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let merkle_tree_path = args.get(1).ok_or("Error: No merkle tree file provided")?;
    let merkle_root_path = args.get(2).ok_or("Error: No merkle root file provided")?;
    process_input_json(&merkle_tree_path, &merkle_root_path, "./out.bin")
}
