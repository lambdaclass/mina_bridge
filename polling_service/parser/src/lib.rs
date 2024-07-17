use std::{fs, path::PathBuf, str::FromStr as _};

use reqwest::header::CONTENT_TYPE;
use serde_json::Value;

pub fn fetch_mina_state(mina_rpc_url: &str) -> Result<(), String> {
    let state_hash_response = query_state_hash(mina_rpc_url)
        .map_err(|err| format!("Error querying state hash: {err}"))?;
    let state_hash = parse_state_hash(&state_hash_response)?;

    let state_proof_response = query_state_proof_base64(mina_rpc_url, &state_hash)
        .map_err(|err| format!("Error querying state proof: {err}"))?;
    let state_proof = parse_state_proof(&state_proof_response)?;

    let mut state_hash_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    state_hash_path.push("../../protocol_state_hash.pub");
    fs::write(state_hash_path, state_hash)
        .map_err(|err| format!("Error writing state hash to file: {err}"))?;

    let mut state_proof_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    state_proof_path.push("../../protocol_state_proof.proof");
    fs::write(state_proof_path, state_proof)
        .map_err(|err| format!("Error writing state proof to file: {err}"))
}

fn query_state_hash(mina_rpc_url: &str) -> Result<Value, String> {
    let response = reqwest::blocking::Client::new()
        .post(mina_rpc_url)
        .header(CONTENT_TYPE, "application/json")
        .body(
            "{\"query\": \"{
                bestChain(maxLength: 1) {
                    protocolState {
                        previousStateHash
                    }
                }
            }\"}",
        )
        .send()
        .map_err(|err| format!("Error making request for state hash: {err}"))?
        .text()
        .map_err(|err| format!("Error getting text of state hash: {err}"))?;

    let response_value = serde_json::Value::from_str(&response)
        .map_err(|err| format!("Error building JSON value of state hash: {err}"))?;

    response_value
        .get("data")
        .and_then(|v| v.get("bestChain"))
        .and_then(|v| v.get(0).cloned())
        .ok_or("Could not get 'data.bestChain[0]' field in state hash response".to_owned())
}

fn query_state_proof_base64(mina_rpc_url: &str, state_hash: &str) -> Result<Value, String> {
    let response = reqwest::blocking::Client::new()
        .post(mina_rpc_url)
        .header(CONTENT_TYPE, "application/json")
        .body(format!(
            "{{\"query\": \"{{
                block(stateHash: \\\"{}\\\") {{
                    protocolStateProof {{
                        base64
                    }}
                }}
            }}\"}}",
            state_hash
        ))
        .send()
        .map_err(|err| format!("Error making request for state proof: {err}"))?
        .text()
        .map_err(|err| format!("Error getting text of state proof: {err}"))?;

    let response_value = serde_json::Value::from_str(&response)
        .map_err(|err| format!("Error building JSON value of state proof: {err}"))?;

    response_value
        .get("data")
        .and_then(|v| v.get("block").cloned())
        .ok_or("Could not get 'data.bestChain[0]' field in state proof response".to_owned())
}

fn parse_state_hash(query: &Value) -> Result<String, String> {
    let ret = query
        .get("protocolState")
        .and_then(|v| v.get("previousStateHash"))
        .and_then(Value::as_str)
        .ok_or(format!(
            "Error getting 'protocolState.previousStateHash' in response"
        ))?;

    Ok(ret.to_string())
}

fn parse_state_proof(query: &Value) -> Result<String, String> {
    let ret = query
        .get("protocolStateProof")
        .and_then(|v| v.get("base64"))
        .and_then(Value::as_str)
        .ok_or(format!(
            "Error getting 'protocolState.previousStateHash' in response"
        ))?;

    Ok(ret.to_string())
}

#[cfg(test)]
mod tests {
    use crate::fetch_mina_state;

    #[test]
    fn fetch_mina_state_works() {
        fetch_mina_state("http://localhost:3085/graphql").unwrap();
    }
}
