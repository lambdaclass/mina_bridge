pub mod merkle_root;

use crate::merkle_root::MerkleRoot;

/// Queries the Mina node to get a Merkle root and parses it from the response and writes it to a file.
///
/// # Arguments
///
/// * `rpc_url` - The URL of the Mina node GraphQL API.
/// * `output_path` - A string slice that holds the path to the output file.
///
/// # Errors
///
/// If the file cannot be written to, an error will be returned.
pub fn query_and_parse_merkle_root(rpc_url: &str, output_path: &str) -> Result<(), String> {
    let received_merkle_root = MerkleRoot::query_merkle_root(rpc_url)
        .map_err(|err| format!("Error querying merkle root: {err}"))?;
    std::fs::write(
        output_path,
        received_merkle_root
            .data
            .daemon_status
            .ledger_merkle_root
            .clone(),
    )
    .map_err(|err| format!("Error writing to file: {err}"))
}
