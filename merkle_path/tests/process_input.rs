#[cfg(test)]
mod test {
    use merkle_path::process_input_json;
    #[test]
    fn test_input_json() {
        process_input_json(
            "http://5.9.57.89:3085/graphql",
            "./tests/public_key.txt",
            "./tests/leaf_hash.bin",
            "./tests/merkle_path.bin",
        )
        .unwrap();
    }
}
