#[cfg(test)]
mod test {
    use merkle_root_parser::query_and_parse_merkle_root;
    #[test]
    fn test_merkle_root() {
        query_and_parse_merkle_root("http://5.9.57.89:3085/graphql", "./tests/merkle_root.txt")
            .unwrap();
    }
}
