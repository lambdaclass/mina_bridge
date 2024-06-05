pub mod merkle_root;

use crate::merkle_root::MerkleRoot;
use std::io::{Error, ErrorKind};

/// Parse the merkle root from the response and write it to a file.
///
/// # Arguments
///
/// * `output_path` - A string slice that holds the path to the output file.
///
/// # Errors
///
/// If the file cannot be written to, an error will be returned.
pub fn parse_merkle_root(output_path: &str) -> Result<(), Error> {
    let received_merkle_root = MerkleRoot::query_merkle_root().map_err(|err| {
        Error::new(
            ErrorKind::Other,
            format!("Error querying merkle root: {err}"),
        )
    })?;
    std::fs::write(
        output_path,
        received_merkle_root
            .data
            .daemon_status
            .ledger_merkle_root
            .clone(),
    )
}
