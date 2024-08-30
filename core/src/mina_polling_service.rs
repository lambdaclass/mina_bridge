use std::str::FromStr;

use aligned_sdk::core::types::{Chain, ProvingSystemId, VerificationData};
use base64::prelude::*;
use ethers::types::Address;
use futures::future::join_all;
use graphql_client::{
    reqwest::{post_graphql, post_graphql_blocking},
    GraphQLQuery,
};
use kimchi::mina_curves::pasta::Fp;
use kimchi::o1_utils::FieldHelpers;
use log::{debug, info};
use mina_p2p_messages::{
    binprot::BinProtRead,
    v2::{LedgerHash, MinaBaseProofStableV2, MinaStateProtocolStateValueStableV2, StateHash},
};
use mina_tree::MerklePath;
use sha3::Digest;

use crate::{
    proof::state_proof::{MinaStateProof, MinaStatePubInputs},
    smart_contract_utility::get_bridge_tip_hash,
    utils::constants::BRIDGE_TRANSITION_FRONTIER_LEN,
};

type StateHashAsDecimal = String;
type PrecomputedBlockProof = String;
type FieldElem = String;

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
    let bridge_tip_state_hash = get_bridge_tip_hash(chain, eth_rpc_url).await?.0;
    let (
        candidate_chain_states,
        candidate_chain_state_hashes,
        candidate_chain_ledger_hashes,
        candidate_tip_proof,
    ) = query_candidate_chain(rpc_url).await?;

    let candidate_tip_state_hash = candidate_chain_state_hashes
        .last()
        .ok_or("Missing candidate tip state hash".to_string())?;

    if bridge_tip_state_hash == *candidate_tip_state_hash {
        return Err("Candidate chain is already verified".to_string());
    }

    let bridge_tip_state = query_state(rpc_url, &bridge_tip_state_hash).await?;

    info!("Queried Mina candidate chain with tip {candidate_tip_state_hash} and its proof");

    let pub_input = MinaStatePubInputs {
        bridge_tip_state_hash,
        candidate_chain_state_hashes,
        candidate_chain_ledger_hashes,
    };
    let proof = MinaStateProof {
        candidate_tip_proof,
        candidate_chain_states,
        bridge_tip_state,
    };

    let proof = bincode::serialize(&proof)
        .map_err(|err| format!("Failed to serialize state proof: {err}"))?;
    let pub_input = Some(
        bincode::serialize(&pub_input)
            .map_err(|err| format!("Failed to serialize public inputs: {err}"))?,
    );

    let proof_generator_addr =
        Address::from_str(proof_generator_addr).map_err(|err| err.to_string())?;

    Ok(VerificationData {
        proving_system: ProvingSystemId::Mina,
        proof,
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
    let state_hash = get_bridge_tip_hash(chain, eth_rpc_url).await?.0;
    let (ledger_hash, account_hash, merkle_proof, account_id_hash) =
        query_merkle(rpc_url, &state_hash.to_string(), public_key).await?;

    let proof = merkle_proof
        .into_iter()
        .flat_map(|node| {
            match node {
                MerklePath::Left(hash) => [vec![0], hash.to_bytes()],
                MerklePath::Right(hash) => [vec![1], hash.to_bytes()],
            }
            .concat()
        })
        .collect();

    let pub_input = Some(
        [
            ledger_hash.to_fp().unwrap().to_bytes(), // TODO(xqft): this is temporary
            account_hash.to_bytes(),
            account_id_hash.to_vec(),
        ]
        .concat(),
    );

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

pub async fn query_state(
    rpc_url: &str,
    state_hash: &StateHash,
) -> Result<MinaStateProtocolStateValueStableV2, String> {
    let variables = state_query::Variables {
        state_hash: state_hash.to_string(),
    };
    debug!("Querying state {}", variables.state_hash);
    let client = reqwest::Client::new();
    let proof = post_graphql::<StateQuery, _>(&client, rpc_url, variables)
        .await
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing state query response data".to_string())
        .map(|response| response.protocol_state)
        .and_then(|base64| {
            BASE64_STANDARD
                .decode(base64)
                .map_err(|err| format!("Couldn't decode state from base64: {err}"))
        })
        .and_then(|binprot| {
            MinaStateProtocolStateValueStableV2::binprot_read(&mut binprot.as_slice())
                .map_err(|err| format!("Couldn't read state binprot: {err}"))
        })?;
    Ok(proof)
}

pub async fn query_candidate_chain(
    rpc_url: &str,
) -> Result<
    (
        [MinaStateProtocolStateValueStableV2; BRIDGE_TRANSITION_FRONTIER_LEN],
        [StateHash; BRIDGE_TRANSITION_FRONTIER_LEN],
        [LedgerHash; BRIDGE_TRANSITION_FRONTIER_LEN],
        MinaBaseProofStableV2,
    ),
    String,
> {
    debug!("Querying for candidate state");
    let client = reqwest::blocking::Client::new();
    let variables = best_chain_query::Variables {
        max_length: BRIDGE_TRANSITION_FRONTIER_LEN
            .try_into()
            .map_err(|_| "Transition frontier length conversion failure".to_string())?,
    };
    let response = post_graphql_blocking::<BestChainQuery, _>(&client, rpc_url, variables)
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing candidate query response data".to_string())?;
    let best_chain = response
        .best_chain
        .ok_or("Missing best chain field".to_string())?;
    if best_chain.len() != BRIDGE_TRANSITION_FRONTIER_LEN {
        return Err(format!(
            "Not enough blocks ({}) were returned from query",
            best_chain.len()
        ));
    }
    let chain_state_hashes: [StateHash; BRIDGE_TRANSITION_FRONTIER_LEN] = best_chain
        .iter()
        .map(|state| state.state_hash.clone())
        .collect::<Vec<StateHash>>()
        .try_into()
        .map_err(|_| "Failed to convert chain state hashes vector into array".to_string())?;
    let chain_ledger_hashes: [LedgerHash; BRIDGE_TRANSITION_FRONTIER_LEN] = best_chain
        .iter()
        .map(|state| {
            state
                .protocol_state
                .blockchain_state
                .staged_ledger_hash
                .clone()
        })
        .collect::<Vec<LedgerHash>>()
        .try_into()
        .map_err(|_| "Failed to convert chain ledger hashes vector into array".to_string())?;

    let chain_states = join_all(
        chain_state_hashes
            .iter()
            .map(|state_hash| query_state(rpc_url, state_hash)),
    )
    .await
    .into_iter()
    .collect::<Result<Vec<_>, _>>()
    .and_then(|states| {
        states
            .try_into()
            .map_err(|_| "Couldn't convert vector of states to array".to_string())
    })?;

    let tip = best_chain.last().ok_or("Missing best chain".to_string())?;
    let tip_state_proof = tip
        .protocol_state_proof
        .base64
        .clone()
        .ok_or("No tip state proof".to_string())
        .and_then(|base64| {
            BASE64_URL_SAFE
                .decode(base64)
                .map_err(|err| format!("Couldn't decode state proof from base64: {err}"))
        })
        .and_then(|binprot| {
            MinaBaseProofStableV2::binprot_read(&mut binprot.as_slice())
                .map_err(|err| format!("Couldn't read state proof binprot: {err}"))
        })?;

    Ok((
        chain_states,
        chain_state_hashes,
        chain_ledger_hashes,
        tip_state_proof,
    ))
}

pub async fn query_root(rpc_url: &str, length: usize) -> Result<StateHash, String> {
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
    Ok(root.state_hash.clone())
}

pub async fn query_merkle(
    rpc_url: &str,
    state_hash: &str,
    public_key: &str,
) -> Result<(LedgerHash, Fp, Vec<MerklePath>, [u8; 32]), String> {
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

    let ledger_hash = response
        .block
        .protocol_state
        .blockchain_state
        .staged_ledger_hash;

    let account_hash = Fp::from_str(&account.leaf_hash.ok_or("Missing merkle query leaf hash")?)
        .map_err(|_| "Error deserializing leaf hash".to_string())?;

    let merkle_proof = account
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

    // TODO(xqft): This definition for account_hash is a placeholder until we have the GraphQL
    // query for the complete data of an account. The real definition would be:
    //
    // let account_id_bytes =
    //     [account.compressed_public_key.x, account.compressed_public_key.is_odd, account.token_id]
    //     .map(to_bytes)
    //     .concat();
    //
    // let account_id_hash = Keccak256(account_id)
    let mut hasher = sha3::Keccak256::new();
    hasher.update(account_hash.to_bytes());
    let account_id_hash = hasher.finalize_reset().into();

    Ok((ledger_hash, account_hash, merkle_proof, account_id_hash))
}
