use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();

    let path = &args[1];
    process_input_json(path, "./out.bin")
}
