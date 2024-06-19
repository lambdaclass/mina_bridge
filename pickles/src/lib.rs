use std::fs;

use state_proof::parse;
// use verifier::verify;

pub mod state_proof;
pub mod verifier;

pub fn parse_and_verify(proof_file_path: &str) -> Result<(), String> {
    let proof_json = fs::read_to_string(proof_file_path)
        .map_err(|err| format!("Could not read proof file: {err}"))?;
    let proof = parse(&proof_json)?;

    Ok(())
}
