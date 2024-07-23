use std::{fs, str::FromStr as _};

use kimchi::o1_utils::FieldHelpers;
use mina_curves::pasta::Fp;
use reqwest::header::CONTENT_TYPE;

const STATE_HASH_SIZE: usize = 32;
const PROTOCOL_STATE_SIZE: usize = 2060;

// TODO(gabrielbosio): These are temporary, we will fetch the tip from the Mina contract instead of using these hardcoded values.
const TIP_PROTOCOL_STATE: &str = "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";
const TIP_STATE_HASH_FIELD: &str =
    "12084457152680218729886082143527083418960607731606306285579721808430391800104";

pub fn parse_public_input(
    rpc_url: &str,
    proof_path: &str,
    public_input_path: &str,
) -> Result<(), String> {
    let tip_state_hash_field = serialize_state_hash_field(TIP_STATE_HASH_FIELD)
        .map_err(|err| format!("Error serializing tip's state hash field: {err}"))?;
    let tip_protocol_state = serialize_protocol_state(TIP_PROTOCOL_STATE)
        .map_err(|err| format!("Error serializing tip's protocol state: {err}"))?;

    let last_block_value = query_last_block(rpc_url)?;

    let proof = serialize_protocol_state_proof(&last_block_value)?;

    let mut public_input = get_state_hash_field(&last_block_value)?;
    public_input.extend(get_protocol_state(&last_block_value)?);
    public_input.extend(tip_state_hash_field);
    public_input.extend(tip_protocol_state);

    fs::write(proof_path, proof)
        .map_err(|err| format!("Error writing state proof to file: {err}"))?;
    fs::write(public_input_path, public_input)
        .map_err(|err| format!("Error writing public input to file: {err}"))
}

fn query_last_block(rpc_url: &str) -> Result<serde_json::Value, String> {
    let body = "{\"query\": \"{
            protocolState(encoding: BASE64)
            bestChain(maxLength: 1) {
                stateHashField
                protocolStateProof {
                    base64
                }
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

fn get_state_hash_field(response_value: &serde_json::Value) -> Result<Vec<u8>, String> {
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

    serialize_state_hash_field(state_hash_field_str)
}

fn serialize_state_hash_field(state_hash_field_str: &str) -> Result<Vec<u8>, String> {
    let state_hash_field = Fp::from_str(state_hash_field_str).map_err(|_| {
        format!(
            "Error converting state hash to field: {:?}",
            &state_hash_field_str
        )
    })?;
    let state_hash_field_bytes = state_hash_field.to_bytes();

    debug_assert_eq!(state_hash_field_bytes.len(), STATE_HASH_SIZE);

    Ok(state_hash_field_bytes)
}

fn get_protocol_state(response_value: &serde_json::Value) -> Result<Vec<u8>, String> {
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

    serialize_protocol_state(protocol_state_str)
}

fn serialize_protocol_state(protocol_state_str: &str) -> Result<Vec<u8>, String> {
    let protocol_state_bytes = protocol_state_str.as_bytes().to_vec();

    debug_assert_eq!(protocol_state_bytes.len(), PROTOCOL_STATE_SIZE);

    Ok(protocol_state_bytes)
}

fn serialize_protocol_state_proof(response_value: &serde_json::Value) -> Result<Vec<u8>, String> {
    let protocol_state_proof_str = response_value
        .get("bestChain")
        .and_then(|d| d.get(0))
        .and_then(|d| d.get("protocolStateProof"))
        .and_then(|d| d.get("base64"))
        .ok_or(format!(
            "Error getting 'bestChain[0].protocolStateProof.base64' from {:?}",
            response_value
        ))?
        .as_str()
        .ok_or(format!(
            "Error converting protocol state proof value to string: {:?}",
            response_value,
        ))?;
    let protocol_state_proof_bytes = protocol_state_proof_str.as_bytes().to_vec();

    Ok(protocol_state_proof_bytes)
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use crate::parse_public_input;

    #[test]
    fn serialize_and_deserialize() {
        let mut proof_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        proof_path.push("protocol_state.proof");
        let mut public_input_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        public_input_path.push("protocol_state.pub");

        parse_public_input(
            "http://5.9.57.89:3085/graphql",
            proof_path.to_str().unwrap(),
            public_input_path.to_str().unwrap(),
        )
        .unwrap();
    }
}
