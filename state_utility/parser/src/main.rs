use merkle_root_parser::parse_merkle_root;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let merkle_root_out_path = args.get(1).ok_or("Error: No merkle root file provided")?;
    parse_merkle_root(merkle_root_out_path)
}
