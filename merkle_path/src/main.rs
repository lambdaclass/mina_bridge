use merkle_path::process_input_json;

fn main() -> Result<(), String> {
    let input_path = std::env::args()
        .nth(1)
        .ok_or("Error: No input file provided")?;
    process_input_json(&input_path, "./out.bin")
}
