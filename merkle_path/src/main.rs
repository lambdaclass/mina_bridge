use merkle_path::process_input_json;

fn main() -> Result<(), String> {
<<<<<<< HEAD
    let mut args = std::env::args();

    let merkle_tree_path = args.nth(1).ok_or("Error: No merkle tree file provided")?;
    let merkle_root_path = args.nth(2).ok_or("Error: No merkle root file provided")?;
    process_input_json(&merkle_tree_path, &merkle_root_path, "./out.bin")
=======
    let input_path = std::env::args()
        .nth(1)
        .ok_or("Error: No input file provided")?;
    process_input_json(&input_path, "./out.bin")
>>>>>>> main
}
