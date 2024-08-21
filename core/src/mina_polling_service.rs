use std::str::FromStr as _;

use aligned_sdk::core::types::{Chain, ProvingSystemId, VerificationData};
use base64::prelude::*;
use ethers::types::Address;
use graphql_client::{
    reqwest::{post_graphql, post_graphql_blocking},
    GraphQLQuery,
};
use kimchi::{o1_utils::FieldHelpers, turshi::helper::CairoFieldHelpers};
use log::{debug, info};
use mina_curves::pasta::Fp;
use mina_p2p_messages::{
    binprot::BinProtRead,
    v2::{LedgerHash as MerkleRoot, MinaStateProtocolStateValueStableV2, StateHash},
};
use mina_tree::{FpExt, MerklePath};

use crate::{smart_contract_utility::get_tip_state_hash, utils::constants::MINA_HASH_SIZE};

type StateHashAsDecimal = String;
type PrecomputedBlockProof = String;
type ProtocolState = String;
type FieldElem = String;
type LedgerHash = String;

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

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/graphql/mina_schema.json",
    query_path = "src/graphql/merkle_query.graphql"
)]
/// A query for retrieving the merkle root, leaf and path of an account
/// included in some state.
struct MerkleQuery;

pub async fn get_mina_proof_of_state(
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

    let candidate_merkle_root = serialize_ledger_hash(&candidate_state)?;

    let candidate_hash = serialize_state_hash(&candidate_hash)?;
    let candidate_state = serialize_state(candidate_state);
    let candidate_proof = serialize_state_proof(&candidate_proof);

    let mut pub_input = candidate_merkle_root;
    pub_input.extend(candidate_hash);
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

pub async fn get_mina_proof_of_account(
    public_key: &str,
    rpc_url: &str,
    proof_generator_addr: &str,
    chain: &Chain,
    eth_rpc_url: &str,
) -> Result<VerificationData, String> {
    let state_hash = get_tip_state_hash(chain, eth_rpc_url).await?;
    let (merkle_root, account_hash, merkle_path) = query_merkle(
        rpc_url,
        &StateHash::from_fp(state_hash).to_string(),
        public_key,
    )
    .await?;

    let proof = merkle_path
        .into_iter()
        .flat_map(|node| {
            match node {
                MerklePath::Left(hash) => [vec![0], hash.to_bytes()],
                MerklePath::Right(hash) => [vec![1], hash.to_bytes()],
            }
            .concat()
        })
        .collect();

    let pub_input = Some([merkle_root.to_bytes(), account_hash.to_bytes()].concat());

    let proof_generator_addr =
        Address::from_str(proof_generator_addr).map_err(|err| err.to_string())?;

    Ok(VerificationData {
        proving_system: ProvingSystemId::MinaAccount,
        proof,
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

pub async fn query_merkle(
    rpc_url: &str,
    state_hash: &str,
    public_key: &str,
) -> Result<(Fp, Fp, Vec<MerklePath>), String> {
    debug!("Querying merkle root, leaf and path of account {public_key} of state {state_hash}");
    let client = reqwest::Client::new();

    let variables = merkle_query::Variables {
        state_hash: state_hash.to_owned(),
        public_key: public_key.to_owned(),
    };

    let response = post_graphql::<MerkleQuery, _>(&client, rpc_url, variables)
        .await
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing merkle query response data".to_string())?;

    let account = response
        .account
        .ok_or("Missing merkle query account".to_string())?;

    let merkle_root = MerkleRoot::from_str(
        &response
            .block
            .protocol_state
            .blockchain_state
            .staged_ledger_hash,
    )
    .map_err(|_| "Error deserializing leaf hash".to_string())?
    .to_fp()
    .map_err(|_| "Error decoding leaf hash into fp".to_string())?;

    let merkle_leaf = Fp::from_str(&account.leaf_hash.ok_or("Missing merkle query leaf hash")?)
        .map_err(|_| "Error deserializing leaf hash".to_string())?;

    let merkle_path = account
        .merkle_path
        .ok_or("Missing merkle query path")?
        .into_iter()
        .map(|node| -> Result<MerklePath, ()> {
            match (node.left, node.right) {
                (Some(fp_str), None) => Ok(MerklePath::Left(Fp::from_str(&fp_str)?)),
                (None, Some(fp_str)) => Ok(MerklePath::Right(Fp::from_str(&fp_str)?)),
                _ => unreachable!(),
            }
        })
        .collect::<Result<Vec<MerklePath>, ()>>()
        .map_err(|_| "Error deserializing merkle path nodes".to_string())?;

    Ok((merkle_root, merkle_leaf, merkle_path))
}

fn serialize_state_hash(hash: &StateHashAsDecimal) -> Result<Vec<u8>, String> {
    let bytes = Fp::from_str(hash)
        .map_err(|_| "Failed to decode hash as a field element".to_string())?
        .to_bytes();
    if bytes.len() != MINA_HASH_SIZE {
        return Err(format!(
            "Failed to encode hash as bytes: length is not exactly {MINA_HASH_SIZE}."
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

fn serialize_ledger_hash(state: &ProtocolState) -> Result<Vec<u8>, String> {
    BASE64_STANDARD
        .decode(state)
        .map_err(|err| err.to_string())
        .and_then(|binprot| {
            MinaStateProtocolStateValueStableV2::binprot_read(&mut binprot.as_slice())
                .map_err(|err| err.to_string())
        })
        .and_then(|state| {
            state
                .body
                .blockchain_state
                .staged_ledger_hash
                .non_snark
                .ledger_hash
                .to_fp()
                .map_err(|err| err.to_string())
        })
        .map(|ledger_hash| ledger_hash.to_bytes())
}
