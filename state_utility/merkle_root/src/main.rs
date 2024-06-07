use merkle_root::process_merkle_root;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let merkle_root_in_path = args.get(1).ok_or("Error: No merkle root file provided")?;
    let merkle_root_evm_out_path = args.get(2).ok_or("Error: No merkle root EVM out path")?;
    let merkle_root_o1js_out_path = args.get(3).ok_or("Error: No merkle root o1js out path")?;
    process_merkle_root(merkle_root_in_path, merkle_root_evm_out_path, merkle_root_o1js_out_path)
}
