pub mod account;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use merkle_path::MerkleTree;
use serialize::EVMSerializable;
use std::fs;
use std::io::Write;

pub fn process_input_json(input_path: &str, output_path: &str) {
    let content = std::fs::read_to_string(input_path).unwrap();
    let deserialized: MerkleTree = serde_json::from_str(&content).unwrap();
    let ret_to_bytes = deserialized.data.account.merkle_path.to_bytes();

    let mut file = fs::OpenOptions::new()
        .create(true) // To create a new file
        .truncate(true)
        .write(true)
        .open(output_path)
        .unwrap();

    file.write_all(&ret_to_bytes).unwrap();
}
