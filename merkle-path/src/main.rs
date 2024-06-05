pub mod account;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use crate::merkle_path::MerkleTree;
use merkle_path::MerkleLeaf;
use serialize::EVMSerializable;
use std::env;
use std::fs;
use std::io::Write;

//static PUBLIC_KEY: &str = "B62qjpfEV5NEK2LMHqD5t7KkEYcZvsqwf7RBz4qz2hXX5vZPDSF7U9s";

fn main() {
    let args: Vec<String> = env::args().collect();

    let input_file = &args[1];
    let content = std::fs::read_to_string(input_file).unwrap();
    let deserialized: MerkleTree = serde_json::from_str(&content).unwrap();
    let ret_to_bytes = deserialized.data.account.merkle_path.to_bytes();

    let mut file = fs::OpenOptions::new()
        .create(true) // To create a new file
        .write(true)
        .open("./out.bin")
        .unwrap();

    file.write_all(&ret_to_bytes).unwrap();
}
