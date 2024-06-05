pub mod field;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use merkle_path::MerkleTree;
use mina_hasher::Fp;
use serialize::EVMSerializable;
use std::fs;
use std::io::Write;

pub fn process_input_json(
    merkle_root_in_path: &str,
    merkle_root_out_path: &str,
) -> Result<(), String> {
    let merkle_root_content = std::fs::read_to_string(merkle_root_path)
        .map_err(|err| format!("Error opening file {err}"))?;
    let merkle_root: Fp = field::from_str(&merkle_root_content)
        .map_err(|err| format!("Error deserializing Merkle root to field {err}"))?;

    let mut merkle_root_file = fs::OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(merkle_root_path)
        .map_err(|err| format!("Error creating file {err}"))?;

    merkle_tree_file
        .write_all(&field::to_bytes(&merkle_root)?)
        .map_err(|err| format!("Error writing to output file {err}"))
}
