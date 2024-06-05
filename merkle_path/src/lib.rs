pub mod field;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use merkle_path::MerkleTree;
use mina_hasher::Fp;
use serialize::EVMSerializable;
use std::fs;
use std::io::Write;

/// Reads input JSON file, deserializes it to `MerkleTree`, and writes the `MerklePath` to a binary file.
///
/// # Arguments
///
/// * `input_path` - A string slice that holds the path to the input JSON file.
/// * `output_path` - A string slice that holds the path to the output binary file.
///
/// # Errors
///
/// Returns a string slice with an error message if the file cannot be opened,
/// the content cannot be deserialized to JSON,
/// or the output file cannot be created or written to.
pub fn process_input_json(
    merkle_tree_path: &str,
    merkle_root_path: &str,
    output_path: &str,
) -> Result<(), String> {
    let merkle_tree_content = std::fs::read_to_string(merkle_tree_path)
        .map_err(|err| format!("Error opening file {err}"))?;
    let merkle_tree: MerkleTree = serde_json::from_str(&merkle_tree_content)
        .map_err(|err| format!("Error deserializing content to JSON {err}"))?;

    let merkle_root_content = std::fs::read_to_string(merkle_root_path)
        .map_err(|err| format!("Error opening file {err}"))?;
    let merkle_root: Fp = field::from_str(&merkle_root_content)
        .map_err(|err| format!("Error deserializing content to JSON {err}"))?;

    let ret_to_bytes = [
        merkle_tree.data.account.merkle_path.to_bytes(),
        field::to_bytes(&merkle_root)?,
    ]
    .concat();

    let mut file = fs::OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(output_path)
        .map_err(|err| format!("Error creating file {err}"))?;

    file.write_all(&ret_to_bytes)
        .map_err(|err| format!("Error writing to output file {err}"))
}
