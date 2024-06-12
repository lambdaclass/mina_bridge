use merkle_root_parser::query_and_parse_merkle_root;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;
    let merkle_root_out_path = args.get(2).ok_or("Error: No merkle root file provided")?;
    query_and_parse_merkle_root(rpc_url, merkle_root_out_path)
}
