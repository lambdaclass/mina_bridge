use std::{fs, path::PathBuf, str::FromStr as _};

use kimchi::o1_utils::FieldHelpers;
use mina_curves::pasta::Fp;
use reqwest::header::CONTENT_TYPE;

pub fn parse_public_input(rpc_url: &str) -> Result<(), String> {
    let response_value = query_to_mina_node(rpc_url)?;
    let mut public_input = serialize_state_hash_field(&response_value)?;
    public_input.extend(serialize_protocol_state(&response_value)?);

    let mut state_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    state_path.push("../../protocol_state.pub");
    fs::write(state_path, public_input)
        .map_err(|err| format!("Error writing state proof to file: {err}"))
}

fn query_to_mina_node(rpc_url: &str) -> Result<serde_json::Value, String> {
    let body = "{\"query\": \"{
            protocolState(encoding: BASE64)
            bestChain(maxLength: 1) {
                stateHashField
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

    response_value.get("data").cloned().ok_or(format!(
        "Error getting 'data' from response: {:?}",
        response
    ))
}

fn serialize_state_hash_field(response_value: &serde_json::Value) -> Result<Vec<u8>, String> {
    let state_hash_field_str = response_value
        .get("bestChain")
        .and_then(|d| d.get(0))
        .and_then(|d| d.get("stateHashField"))
        .ok_or(format!(
            "Error getting 'bestChain[0].stateHashField' from {:?}",
            response_value
        ))?
        .as_str()
        .ok_or(format!(
            "Error converting state hash value to string: {:?}",
            response_value,
        ))?;
    let state_hash_field = Fp::from_str(state_hash_field_str).map_err(|_| {
        format!(
            "Error converting state hash to field: {:?}",
            &state_hash_field_str
        )
    })?;
    let state_hash_field_bytes = state_hash_field.to_bytes();

    Ok(state_hash_field_bytes)
}

fn serialize_protocol_state(response_value: &serde_json::Value) -> Result<Vec<u8>, String> {
    let protocol_state_str = response_value
        .get("protocolState")
        .ok_or(format!(
            "Error getting 'protocolState' from {:?}",
            response_value
        ))?
        .as_str()
        .ok_or(format!(
            "Error converting protocol state value to string: {:?}",
            response_value,
        ))?;
    let protocol_state_bytes = protocol_state_str.as_bytes().to_vec();

    Ok(protocol_state_bytes)
}
