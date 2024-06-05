use merkle_path::process_input_json;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let merkle_tree_path = &args[1];
    let merkle_root_path = &args[2];
    process_input_json(merkle_tree_path, merkle_root_path, "./out.bin");
}
