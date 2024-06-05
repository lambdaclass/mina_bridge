pub mod account;
pub mod field;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use merkle_path::MerkleTree;
use mina_hasher::Fp;
use serialize::EVMSerializable;
use std::fs;
use std::io::Write;

pub fn process_input_json(merkle_tree_path: &str, merkle_root_path: &str, output_path: &str) {
    let meklre_tree_content = std::fs::read_to_string(merkle_tree_path).unwrap();
    let meklre_tree: MerkleTree = serde_json::from_str(&meklre_tree_content).unwrap();

    let merkle_root_content = std::fs::read_to_string(merkle_root_path).unwrap();
    let merkle_root: Fp = field::from_str(&merkle_root_content).unwrap();

    let ret_to_bytes = [
        meklre_tree.data.account.merkle_path.to_bytes(),
        field::to_bytes(&merkle_root),
    ]
    .concat();

    let mut file = fs::OpenOptions::new()
        .create(true) // To create a new file
        .truncate(true)
        .write(true)
        .open(output_path)
        .unwrap();

    file.write_all(&ret_to_bytes).unwrap();
}
