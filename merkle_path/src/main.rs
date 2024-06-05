use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let path = std::env::args()
        .nth(1)
        .ok_or("Error: No input file provided")?;
    process_input_json(&path, "./out.bin")
}
