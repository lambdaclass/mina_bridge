use std::str::FromStr as _;

use aligned_sdk::core::types::{Chain, ProvingSystemId, VerificationData};
use ethers::types::Address;
use graphql_client::{
    reqwest::{post_graphql, post_graphql_blocking},
    GraphQLQuery,
};
use kimchi::{o1_utils::FieldHelpers, turshi::helper::CairoFieldHelpers};
use log::{debug, info};
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::StateHash;
use mina_tree::FpExt;

use crate::{smart_contract_utility::get_tip_state_hash, utils::constants::MINA_STATE_HASH_SIZE};

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
    query_path = "src/graphql/best_chain_query.graphql"
)]
/// A query for the state hashes and proofs of the transition frontier.
struct BestChainQuery;

pub async fn query_and_serialize(
    rpc_url: &str,
    proof_generator_addr: &str,
    chain: &Chain,
    eth_rpc_url: &str,
) -> Result<VerificationData, String> {
    let tip_hash = get_tip_state_hash(chain, eth_rpc_url).await?.to_decimal();
    let (candidate_hash, candidate_proof) = query_candidate(rpc_url)?;

    if tip_hash == candidate_hash {
        return Err("Candidate state is already verified".to_string());
    }

    let tip_state = query_state(
        rpc_url,
        state_query::Variables {
            state_hash: encode_state_hash(&tip_hash)?,
        },
    )?;

    let candidate_state = query_state(
        rpc_url,
        state_query::Variables {
            state_hash: encode_state_hash(&candidate_hash)?,
        },
    )?;
    info!(
        "Queried Mina candidate state 0x{} and its proof from Mainnet node",
        Fp::from_str(&candidate_hash)
            .map_err(|_| "Failed to decode canddiate state hash".to_string())
            .map(|hash| hash.to_hex_be())?
    );

    let tip_hash = serialize_state_hash(&tip_hash)?;
    let tip_state = serialize_state(tip_state);

    let candidate_hash = serialize_state_hash(&candidate_hash)?;
    let candidate_state = serialize_state(candidate_state);
    let candidate_proof = serialize_state_proof(&candidate_proof);

    let mut pub_input = candidate_hash;
    pub_input.extend(tip_hash);
    pub_input.extend((candidate_state.len() as u32).to_be_bytes());
    pub_input.extend(candidate_state);
    pub_input.extend((tip_state.len() as u32).to_be_bytes());
    pub_input.extend(tip_state);

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
    debug!("Querying state {}", variables.state_hash);
    let client = reqwest::blocking::Client::new();
    let response = post_graphql_blocking::<StateQuery, _>(&client, rpc_url, variables)
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing state query response data".to_string())?;
    Ok(response.protocol_state)
}

pub fn query_candidate(
    rpc_url: &str,
) -> Result<(StateHashAsDecimal, PrecomputedBlockProof), String> {
    debug!("Querying for candidate state");
    let client = reqwest::blocking::Client::new();
    let variables = best_chain_query::Variables { max_length: 1 };
    let response = post_graphql_blocking::<BestChainQuery, _>(&client, rpc_url, variables)
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing candidate query response data".to_string())?;
    let best_chain = response
        .best_chain
        .ok_or("Missing best chain field".to_string())?;
    let tip = best_chain.first().ok_or("Missing best chain".to_string())?;
    let state_hash_field = tip.state_hash_field.clone();
    let protocol_state_proof = tip
        .protocol_state_proof
        .base64
        .clone()
        .ok_or("No protocol state proof".to_string())?;

    Ok((state_hash_field, protocol_state_proof))
}

pub async fn query_root(rpc_url: &str, length: usize) -> Result<StateHashAsDecimal, String> {
    let client = reqwest::Client::new();
    let variables = best_chain_query::Variables {
        max_length: length as i64,
    };
    let response = post_graphql::<BestChainQuery, _>(&client, rpc_url, variables)
        .await
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing root hash query response data".to_string())?;
    let best_chain = response
        .best_chain
        .ok_or("Missing best chain field".to_string())?;
    let root = best_chain.first().ok_or("No root state")?;
    Ok(root.state_hash_field.clone())
}

fn serialize_state_hash(hash: &StateHashAsDecimal) -> Result<Vec<u8>, String> {
    let bytes = Fp::from_str(hash)
        .map_err(|_| "Failed to decode hash as a field element".to_string())?
        .to_bytes();
    if bytes.len() != MINA_STATE_HASH_SIZE {
        return Err(format!(
            "Failed to encode hash as bytes: length is not exactly {MINA_STATE_HASH_SIZE}."
        ));
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

#[cfg(test)]
mod tests {
    use core::panic;

    use aligned_sdk::core::types::Chain;

    use crate::utils::constants::{ANVIL_ETH_RPC_URL, ANVIL_PROOF_GENERATOR_ADDR};

    use super::query_and_serialize;

    #[tokio::test]
    async fn serialize_and_deserialize() {
        let result = query_and_serialize(
            "http://5.9.57.89:3085/graphql",
            ANVIL_PROOF_GENERATOR_ADDR,
            &Chain::Devnet,
            ANVIL_ETH_RPC_URL,
        )
        .await;

        if let Err(err) = result {
            if err != "Candidate state is already verified" {
                panic!();
            }
        }
    }
}
