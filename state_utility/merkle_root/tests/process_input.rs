#[cfg(test)]
mod test {
    use merkle_root::process_merkle_root;
    #[test]
    fn test_process_merkle_root() {
        process_merkle_root("./tests/merkle_root.txt", "./tests/out.bin").unwrap();
    }
}
