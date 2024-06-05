use merkle_root_parser::parse_merkle_root;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let output_path = &args[1];
    parse_merkle_root(output_path).unwrap();
}
