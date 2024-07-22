use parser::parse_public_input;

pub fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let rpc_url = args.get(1).ok_or("Error: No RPC URL provided")?;

    parse_public_input(&rpc_url)
}
