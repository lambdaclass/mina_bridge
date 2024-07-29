use std::str::FromStr as _;

use aligned_sdk::core::types::{ProvingSystemId, VerificationData};
use ethers::types::Address;
use kimchi::o1_utils::FieldHelpers;
use log::{debug, info};
use mina_curves::pasta::Fp;
use reqwest::header::CONTENT_TYPE;

use crate::constants::{MINA_STATE_HASH_SIZE, MINA_TIP_PROTOCOL_STATE, MINA_TIP_STATE_HASH_FIELD};

pub fn query_and_serialize(rpc_url: &str) -> Result<VerificationData, String> {
    let tip_state_hash_field = serialize_state_hash_field(MINA_TIP_STATE_HASH_FIELD)
        .map_err(|err| format!("Error serializing tip's state hash field: {err}"))?;
    let tip_protocol_state = serialize_protocol_state(MINA_TIP_PROTOCOL_STATE)
        .map_err(|err| format!("Error serializing tip's protocol state: {err}"))?;
    let tip_protocol_state_len = tip_protocol_state.len() as u32;
    let mut tip_protocol_state_len_bytes = [0; 4];
    tip_protocol_state_len_bytes.copy_from_slice(&tip_protocol_state_len.to_be_bytes());

    debug!("Querying Mina node for last state and proof");
    let last_block_value = query_last_block(rpc_url)?;

    let proof = serialize_protocol_state_proof(&last_block_value)?;

    let candidate_protocol_state = get_protocol_state(&last_block_value)?;
    let candidate_protocol_state_len = candidate_protocol_state.len() as u32;
    let mut candidate_protocol_state_len_bytes = [0; 4];
    candidate_protocol_state_len_bytes.copy_from_slice(&candidate_protocol_state_len.to_be_bytes());

    let candidate_state_hash = get_state_hash_field(&last_block_value)?;
    info!(
        "Queried Mina candidate state 0x{} and its proof",
        hex::encode(&candidate_state_hash)
    );

    let mut pub_input = candidate_state_hash;
    pub_input.extend(candidate_protocol_state_len_bytes);
    pub_input.extend(candidate_protocol_state);
    pub_input.extend(tip_state_hash_field);
    pub_input.extend(tip_protocol_state_len_bytes);
    pub_input.extend(tip_protocol_state);

    let pub_input = Some(pub_input);

    let proof_generator_addr = Address::from_str(&if let Ok(proof_generator_addr) =
        std::env::var("PROOF_GENERATOR_ADDR")
    {
        proof_generator_addr
    } else {
        "0x66f9664f97F2b50F62D13eA064982f936dE76657".to_string()
    })
    .map_err(|err| err.to_string())?;

    Ok(VerificationData {
        proving_system: ProvingSystemId::Mina,
        proof,
        pub_input,
        verification_key: None,
        vm_program_code: None,
        proof_generator_addr,
    })
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

    debug_assert_eq!(state_hash_field_bytes.len(), MINA_STATE_HASH_SIZE);

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
    use super::query_and_serialize;

    #[test]
    fn serialize_and_deserialize() {
        query_and_serialize("http://5.9.57.89:3085/graphql").unwrap();
    }
}
