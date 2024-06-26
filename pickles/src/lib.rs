use std::fs;

use state_proof::parse;
// use verifier::verify;

pub mod state_proof;
pub mod verifier;

pub fn parse_and_verify(proof_file_path: &str) -> Result<(), String> {
    let proof_json = fs::read_to_string(proof_file_path)
        .map_err(|err| format!("Could not read proof file: {err}"))?;

    let proof_query: serde_json::Map<String, serde_json::Value> = serde_json::from_str(&proof_json)
        .map_err(|err| format!("Could not parse proof file as JSON: {err}"))?;
    let protocol_state_proof = proof_query
        .get("data")
        .and_then(|d| d.get("bestChain"))
        .and_then(|d| d.get(0))
        .and_then(|d| d.get("protocolStateProof"))
        .and_then(|d| d.get("json")).ok_or("Could not parse protocol state proof: JSON structure upto protocolStateProof is unexpected")?;
    let proof = parse(protocol_state_proof)?;

    Ok(())
}
