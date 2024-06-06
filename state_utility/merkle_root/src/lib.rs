pub mod field;

use mina_hasher::Fp;
use std::fs;
use std::io::Write;

/// Receives a path to a file containing a Merkle root in text format, reads the Merkle root,
/// and writes it to a file in binary format.
///
/// # Arguments
///
/// * `merkle_root_in_path` - Path to the file containing the Merkle root in text format.
/// * `merkle_root_out_path` - Path to the file where the Merkle root will be written in binary format.
///
/// # Errors
///
/// * If the file at `merkle_root_in_path` cannot be opened.
/// * If the Merkle root cannot be deserialized to a field element.
/// * If the file at `merkle_root_out_path` cannot be created.
/// * If the Merkle root cannot be written to the output file.
///
pub fn process_merkle_root(
    merkle_root_in_path: &str,
    merkle_root_out_path: &str,
) -> Result<(), String> {
    let merkle_root_content = std::fs::read_to_string(merkle_root_in_path)
        .map_err(|err| format!("Error opening file {err}"))?;
    let merkle_root: Fp = field::from_str(&merkle_root_content)
        .map_err(|err| format!("Error deserializing Merkle root to field {err}"))?;

    let mut merkle_root_file = fs::OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(merkle_root_out_path)
        .map_err(|err| format!("Error creating file {err}"))?;

    merkle_root_file
        .write_all(&field::to_bytes(&merkle_root)?)
        .map_err(|err| format!("Error writing to output file {err}"))
}
