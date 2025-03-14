use std::str::FromStr;

use alloy_sol_types::SolValue;
use base64::prelude::*;
use futures::future::join_all;
use graphql_client::{
    reqwest::{post_graphql, post_graphql_blocking},
    GraphQLQuery,
};
use kimchi::mina_curves::pasta::Fp;
use log::{debug, info};
use mina_p2p_messages::{
    binprot::BinProtRead,
    v2::{
        LedgerHash, MinaBaseAccountBinableArgStableV2 as MinaAccount, MinaBaseProofStableV2,
        MinaStateProtocolStateValueStableV2, StateHash,
    },
};

use crate::{
    eth::get_bridge_tip_hash,
    proof::{
        account_proof::{MerkleNode, MinaAccountProof, MinaAccountPubInputs},
        state_proof::{MinaStateProof, MinaStatePubInputs},
    },
    sol::account::MinaAccountValidationExample,
    utils::constants::BRIDGE_TRANSITION_FRONTIER_LEN,
};

type StateHashAsDecimal = String;
type PrecomputedBlockProof = String;
type FieldElem = String;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/mina_schema.json",
    query_path = "graphql/state_query.graphql"
)]
/// A query for a protocol state given some state hash (non-field).
struct StateQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/mina_schema.json",
    query_path = "graphql/best_chain_query.graphql"
)]
/// A query for the state hashes and proofs of the transition frontier.
struct BestChainQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/mina_schema.json",
    query_path = "graphql/account_query.graphql"
)]
/// A query for retrieving an a Mina account state at some block, along with its ledger hash and
/// merkle path.
struct AccountQuery;

/// Queries data from the Mina State Settlement Ethereum Contract Example and the Mina Node and returns
/// the Mina state proof and its public inputs. These structures can then be serialized and submitted to Aligned Layer.
///
/// The queried data consists of:
/// - Bridge tip state hash from the Mina State Settlement Ethereum Contract Example
/// - Mina candidate chain states from the Mina node
/// - Mina Bridge tip state from the Mina node
pub async fn get_mina_proof_of_state(
    rpc_url: &str,
    eth_rpc_url: &str,
    contract_addr: &str,
    is_state_proof_from_devnet: bool,
) -> Result<(MinaStateProof, MinaStatePubInputs), String> {
    let bridge_tip_state_hash = get_bridge_tip_hash(contract_addr, eth_rpc_url).await?.0;
    let (
        candidate_chain_states,
        candidate_chain_state_hashes,
        candidate_chain_ledger_hashes,
        candidate_tip_proof,
    ) = query_candidate_chain(rpc_url).await?;

    let candidate_tip_state_hash = candidate_chain_state_hashes
        .last()
        .ok_or("Missing candidate tip state hash".to_string())?;

    let bridge_tip_state = query_state(rpc_url, &bridge_tip_state_hash).await?;

    info!("Queried Mina candidate chain with tip {candidate_tip_state_hash} and its proof");

    Ok((
        MinaStateProof {
            candidate_tip_proof,
            candidate_chain_states,
            bridge_tip_state,
        },
        MinaStatePubInputs {
            is_state_proof_from_devnet,
            bridge_tip_state_hash,
            candidate_chain_state_hashes,
            candidate_chain_ledger_hashes,
        },
    ))
}

pub async fn get_mina_proof_of_account(
    public_key: &str,
    state_hash: &str,
    rpc_url: &str,
) -> Result<(MinaAccountProof, MinaAccountPubInputs), String> {
    let (account, ledger_hash, merkle_path) =
        query_account(rpc_url, state_hash, public_key).await?;

    let encoded_account = MinaAccountValidationExample::Account::try_from(&account)?.abi_encode();

    debug!(
        "Retrieved proof of account for ledger {}",
        LedgerHash::from_fp(ledger_hash)
    );

    Ok((
        MinaAccountProof {
            merkle_path,
            account,
        },
        MinaAccountPubInputs {
            ledger_hash,
            encoded_account,
        },
    ))
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
                .snarked_ledger_hash
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

    debug!("Queried state hashes: {chain_state_hashes:?}");
    debug!("Queried ledger hashes: {chain_ledger_hashes:?}");

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

pub async fn query_account(
    rpc_url: &str,
    state_hash: &str,
    public_key: &str,
) -> Result<(MinaAccount, Fp, Vec<MerkleNode>), String> {
    debug!(
        "Querying account {public_key}, its merkle proof and ledger hash for state {state_hash}"
    );
    let client = reqwest::Client::new();

    let variables = account_query::Variables {
        state_hash: state_hash.to_owned(),
        public_key: public_key.to_owned(),
    };

    let response = post_graphql::<AccountQuery, _>(&client, rpc_url, variables)
        .await
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing merkle query response data".to_string())?;

    let membership = response
        .encoded_snarked_ledger_account_membership
        .first()
        .ok_or("Failed to retrieve membership query field".to_string())?;

    let account = BASE64_STANDARD
        .decode(&membership.account)
        .map_err(|err| format!("Failed to decode account from base64: {err}"))
        .and_then(|binprot| {
            MinaAccount::binprot_read(&mut binprot.as_slice())
                .map_err(|err| format!("Failed to deserialize account binprot: {err}"))
        })?;

    debug!(
        "Queried account {} with token id {}",
        account.public_key,
        account.token_id //Into::<TokenIdKeyHash>::into(account.token_id.clone())
    );

    let ledger_hash = response
        .block
        .protocol_state
        .blockchain_state
        .snarked_ledger_hash
        .to_fp()
        .unwrap();

    let merkle_path = membership
        .merkle_path
        .iter()
        .map(|node| -> Result<MerkleNode, ()> {
            match (node.left.as_ref(), node.right.as_ref()) {
                (Some(fp_str), None) => Ok(MerkleNode::Left(Fp::from_str(fp_str)?)),
                (None, Some(fp_str)) => Ok(MerkleNode::Right(Fp::from_str(fp_str)?)),
                _ => unreachable!(),
            }
        })
        .collect::<Result<Vec<_>, ()>>()
        .map_err(|_| "Error deserializing merkle path nodes".to_string())?;

    Ok((account, ledger_hash, merkle_path))
}
