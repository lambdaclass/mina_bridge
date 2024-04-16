/// Returns the bytes corresponding to a 256 bit integer whose bits
/// are mapped to `bools` (1 for true, 0 for false).
pub fn encode_bools_to_uint256_flags_bytes(bools: &[bool]) -> Vec<u8> {
    let mut flags_encoded = vec![0; 32];
    for (i, mut flag) in bools
        .iter()
        .map(|b| if *b { 1 } else { 0 })
        .enumerate()
    {
        flag <<= i % 8; // first flags are positioned on least significant bits
        flags_encoded[i / 8] |= flag;
    }
    flags_encoded.reverse();
    flags_encoded
}
