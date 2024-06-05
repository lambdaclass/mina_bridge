pub mod account;
pub mod merkle_path;
pub mod merkle_root;
pub mod serialize;

use merkle_path::MerkleTree;
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
pub fn process_input_json(input_path: &str, output_path: &str) -> Result<(), String> {
    let content =
        std::fs::read_to_string(input_path).map_err(|err| format!("Error opening file {err}"))?;
    let deserialized: MerkleTree = serde_json::from_str(&content)
        .map_err(|err| format!("Error deserializing content to JSON {err}"))?;
    let ret_to_bytes = deserialized.data.account.merkle_path.to_bytes();

    let mut file = fs::OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(output_path)
        .map_err(|err| format!("Error creating file {err}"))?;

    file.write_all(&ret_to_bytes)
        .map_err(|err| format!("Error writing to output file {err}"))
}
