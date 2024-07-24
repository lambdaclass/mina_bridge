use std::{fs, str::FromStr as _};

use kimchi::o1_utils::FieldHelpers;
use mina_curves::pasta::Fp;
use reqwest::header::CONTENT_TYPE;

const STATE_HASH_SIZE: usize = 32;
const PROTOCOL_STATE_SIZE: usize = 2056;

// TODO(gabrielbosio): These are temporary, we will fetch the tip from the Mina contract instead of using these hardcoded values.
const TIP_PROTOCOL_STATE: &str = "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";
const TIP_STATE_HASH_FIELD: &str =
    "26201757517054449641912404249424749469164718222967816857204695395894215860942";

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
