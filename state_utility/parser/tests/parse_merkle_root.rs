#[cfg(test)]
mod test {
    use merkle_root_parser::parse_merkle_root;
    #[test]
    fn test_merkle_root() {
        parse_merkle_root("./tests/merkle_root.txt").unwrap();
    }
}
