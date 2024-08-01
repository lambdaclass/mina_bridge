use std::str::FromStr as _;

use aligned_sdk::core::types::{ProvingSystemId, VerificationData};
use ethers::types::Address;
use graphql_client::{reqwest::post_graphql_blocking, GraphQLQuery};
use kimchi::{o1_utils::FieldHelpers, turshi::helper::CairoFieldHelpers};
use log::{debug, info};
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::StateHash;
use reqwest::blocking::Client;

use crate::utils::constants::{
    MINA_STATE_HASH_SIZE, MINA_TIP_PROTOCOL_STATE, MINA_TIP_STATE_HASH_FIELD,
};

type StateHashAsDecimal = String;
type PrecomputedBlockProof = String;
type ProtocolState = String;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/graphql/mina_schema.json",
    query_path = "src/graphql/state_query.graphql"
)]
/// A query for a protocol state given some state hash (non-field).
struct StateQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/graphql/mina_schema.json",
    query_path = "src/graphql/candidate_query.graphql"
)]
/// A query for the latest protocol state hash field and proof.
struct CandidateQuery;

pub fn query_and_serialize(
    rpc_url: &str,
    proof_generator_addr: &str,
) -> Result<VerificationData, String> {
    let tip_state_hash_field = serialize_state_hash_field(MINA_TIP_STATE_HASH_FIELD)
        .map_err(|err| format!("Error serializing tip's state hash field: {err}"))?;
    let tip_protocol_state = serialize_protocol_state(MINA_TIP_PROTOCOL_STATE)
        .map_err(|err| format!("Error serializing tip's protocol state: {err}"))?;
    let tip_protocol_state_len = tip_protocol_state.len() as u32;
    let mut tip_protocol_state_len_bytes = [0; 4];
    tip_protocol_state_len_bytes.copy_from_slice(&tip_protocol_state_len.to_be_bytes());

    debug!("Querying Mina node for last state and proof");
    let (candidate_hash, candidate_proof) = query_candidate(rpc_url, candidate_query::Variables)?;
    let candidate_encoded_hash = encode_state_hash(&candidate_hash)?; // used for state query

    let candidate_hash = serialize_state_hash(&candidate_hash)?;
    let candidate_proof = serialize_state_proof(&candidate_proof);

    let candidate_state = query_state(
        rpc_url,
        state_query::Variables {
            state_hash: candidate_encoded_hash,
        },
    )?;
    let candidate_state = serialize_state(candidate_state);

    info!(
        "Queried Mina candidate state 0x{} and its proof from Mainnet node",
        Fp::from_bytes(&candidate_hash)
            .map_err(|err| err.to_string())?
            .to_hex_be()
    );

    let mut pub_input = candidate_hash;
    pub_input.extend(candidate_state.len().to_be_bytes());
    pub_input.extend(candidate_state);
    pub_input.extend(tip_state_hash_field);
    pub_input.extend(tip_protocol_state_len_bytes);
    pub_input.extend(tip_protocol_state);

    let pub_input = Some(pub_input);

    let proof_generator_addr =
        Address::from_str(proof_generator_addr).map_err(|err| err.to_string())?;
    Ok(VerificationData {
        proving_system: ProvingSystemId::Mina,
        proof: candidate_proof,
        pub_input,
        verification_key: None,
        vm_program_code: None,
        proof_generator_addr,
    })
}

pub fn query_state(
    rpc_url: &str,
    variables: state_query::Variables,
) -> Result<ProtocolState, String> {
    let client = Client::new();
    let response = post_graphql_blocking::<StateQuery, _>(&client, rpc_url, variables)
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing state query response data".to_string())?;
    Ok(response.protocol_state)
}

pub fn query_candidate(
    rpc_url: &str,
    variables: candidate_query::Variables,
) -> Result<(PrecomputedBlockProof, StateHashAsDecimal), String> {
    let client = Client::new();
    let response = post_graphql_blocking::<CandidateQuery, _>(&client, rpc_url, variables)
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing candidate query response data".to_string())?;
    let best_chains = response
        .best_chain
        .ok_or("Missing best chain field".to_string())?;
    let best_chain = best_chains
        .first()
        .ok_or("Missing best chain".to_string())?;
    let state_hash_field = best_chain.state_hash_field.clone();
    let protocol_state_proof = best_chain
        .protocol_state_proof
        .base64
        .clone()
        .ok_or("No protocol state proof".to_string())?;

    Ok((state_hash_field, protocol_state_proof))
}

fn serialize_state_hash(hash: &StateHashAsDecimal) -> Result<Vec<u8>, String> {
    let bytes = Fp::from_str(hash)
        .map_err(|_| "Failed to decode hash as a field element".to_string())?
        .to_bytes();
    if bytes.len() != 32 {
        return Err("Failed to encode hash as bytes: length is not exactly 32.".to_string());
    }
    Ok(bytes)
}

fn serialize_state_proof(proof: &PrecomputedBlockProof) -> Vec<u8> {
    proof.as_bytes().to_vec()
}

fn serialize_state(state: ProtocolState) -> Vec<u8> {
    state.as_bytes().to_vec()
}

fn encode_state_hash(hash: &StateHashAsDecimal) -> Result<String, String> {
    Fp::from_str(hash)
        .map_err(|_| "Failed to decode hash as a field element".to_string())
        .map(|fp| StateHash::from_fp(fp).to_string())
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

fn serialize_protocol_state(protocol_state_str: &str) -> Result<Vec<u8>, String> {
    let protocol_state_bytes = protocol_state_str.as_bytes().to_vec();

    Ok(protocol_state_bytes)
}

#[cfg(test)]
mod tests {
    use crate::utils::constants::ANVIL_PROOF_GENERATOR_ADDR;

    use super::query_and_serialize;

    #[test]
    fn serialize_and_deserialize() {
        query_and_serialize("http://5.9.57.89:3085/graphql", ANVIL_PROOF_GENERATOR_ADDR).unwrap();
    }
}
