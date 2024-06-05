#[cfg(test)]
mod test {
    use merkle_path::process_input_json;
    #[test]
    fn test_input_json() {
        process_input_json("./tests/input.json", "./tests/out.bin");
    }
}
