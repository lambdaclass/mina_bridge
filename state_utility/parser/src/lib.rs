use std::{fs, str::FromStr as _};

use kimchi::o1_utils::FieldHelpers;
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::LedgerHash;
use reqwest::header::CONTENT_TYPE;
use serde_json::Value;

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
    let merkle_root_value =
        query_merkle_root(rpc_url).map_err(|err| format!("Error querying merkle root: {err}"))?;
    let merkle_root_str = merkle_root_value.as_str().ok_or(format!(
        "Error converting Merkle root value to string: {:?}",
        merkle_root_value
    ))?;

    let merkle_root = LedgerHash::from_str(merkle_root_str)
        .map_err(|err| format!("Error creating OCaml Ledger hash struct from string: {err}"))?;
    let merkle_root_fp = Fp::from(merkle_root.0.clone());

    fs::write(output_path, merkle_root_fp.to_hex())
        .map_err(|err| format!("Error writing Merkle root to file: {err}"))
}

fn query_merkle_root(rpc_url: &str) -> Result<Value, String> {
    let body = "{\"query\": \"{
            daemonStatus {
              ledgerMerkleRoot
            }
          }\"}"
        .to_owned();
    let client = reqwest::blocking::Client::new();
    let response = client
        .post(rpc_url)
        .header(CONTENT_TYPE, "application/json")
        .body(body)
        .send()
        .map_err(|err| err.to_string())?
        .text()
        .map_err(|err| err.to_string())?;

    let response_value = serde_json::Value::from_str(&response).map_err(|err| err.to_string())?;

    response_value
        .get("data")
        .and_then(|d| d.get("daemonStatus"))
        .and_then(|d| d.get("ledgerMerkleRoot").cloned())
        .ok_or(format!(
            "Could not get 'data.daemonStatus.ledgerMerkleRoot' from {:?}",
            response_value
        ))
}
