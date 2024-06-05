use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let path = args.get(1).ok_or("Error: No input file provided")?;
    process_input_json(path, "./out.bin")
}
