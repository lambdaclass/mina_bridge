pub mod account;
pub mod field;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use crate::merkle_path::MerkleTree;
use merkle_path::MerkleLeaf;
use mina_hasher::Fp;
use serialize::EVMSerializable;
use std::env;
use std::fs;
use std::io::Write;

//static PUBLIC_KEY: &str = "B62qjpfEV5NEK2LMHqD5t7KkEYcZvsqwf7RBz4qz2hXX5vZPDSF7U9s";

fn main() {
    let args: Vec<String> = env::args().collect();

    let response_file = &args[1];
    let response_content = std::fs::read_to_string(response_file).unwrap();
    let response: MerkleTree = serde_json::from_str(&response_content).unwrap();

    let merkle_root_file = &args[2];
    let merkle_root_content = std::fs::read_to_string(merkle_root_file).unwrap();
    let merkle_root: Fp = field::from_str(&merkle_root_content).unwrap();

    let ret_to_bytes = [
        response.data.account.merkle_path.to_bytes(),
        field::to_bytes(&merkle_root),
    ]
    .concat();

    let mut file = fs::OpenOptions::new()
        .create(true) // To create a new file
        .write(true)
        .open("./out.bin")
        .unwrap();

    file.write_all(&ret_to_bytes).unwrap();
}
