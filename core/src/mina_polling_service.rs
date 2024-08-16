use std::str::FromStr as _;

use account_query::AccountAuthRequired;
use aligned_sdk::core::types::{Chain, ProvingSystemId, VerificationData};
use ethers::types::Address;
use graphql_client::{
    reqwest::{post_graphql, post_graphql_blocking},
    GraphQLQuery,
};
use kimchi::{o1_utils::FieldHelpers, turshi::helper::CairoFieldHelpers};
use log::{debug, info};
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::{
    LedgerHash as MerkleRoot, MinaBaseAccountBinableArgStableV2, StateHash, TokenIdKeyHash,
};
use mina_signer::CompressedPubKey;
use mina_tree::{
    scan_state::currency::{self, TxnVersion},
    Account, AuthRequired, FpExt, MerklePath, Permissions, ReceiptChainHash, Timing, TokenSymbol,
    VotingFor,
};

use crate::{smart_contract_utility::get_tip_state_hash, utils::constants::MINA_STATE_HASH_SIZE};

type StateHashAsDecimal = String;
type PrecomputedBlockProof = String;
type ProtocolState = String;
type FieldElem = String;
type LedgerHash = String;
type ChainHash = String;
type PublicKey = String;
type TokenId = String;
type VerificationKey = String;
type AccountNonce = String;
type GlobalSlotSpan = String;
type Globalslot = String;
type Balance = String;
type Amount = String;

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

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/graphql/mina_schema.json",
    query_path = "src/graphql/account_query.graphql"
)]
/// A query for retrieving account data.
struct AccountQuery;

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

pub async fn query_account(rpc_url: &str, public_key: &str) -> Result<Account, String> {
    debug!("Querying account {public_key}");
    let client = reqwest::Client::new();

    let variables = account_query::Variables {
        public_key: public_key.to_owned(),
    };

    let response = post_graphql::<AccountQuery, _>(&client, rpc_url, variables)
        .await
        .map_err(|err| err.to_string())?
        .data
        .ok_or("Missing account query response data".to_string())?;

    let account = response
        .account
        .ok_or("Missing account query account".to_string())?;

    let public_key = CompressedPubKey::from_address(public_key).map_err(|err| err.to_string())?;

    let token_id: mina_tree::TokenId =
        serde_json::from_value::<TokenIdKeyHash>(serde_json::json!(account.token_id))
            .map_err(|err| err.to_string())?
            .into_inner()
            .into();
    let token_symbol = TokenSymbol(account.token_symbol.ok_or("Missing account token symbol")?);
    let balance = currency::Balance::from_u64(
        account
            .balance
            .total
            .parse()
            .map_err(|_| "Could not parse account balance".to_string())?,
    );
    let nonce = currency::Nonce::from_u32(
        account
            .nonce
            .ok_or("Missing account nonce".to_string())?
            .parse()
            .map_err(|_| "Could not parse account balance".to_string())?,
    );
    let receipt_chain_hash = ReceiptChainHash::parse_str(
        &account
            .receipt_chain_hash
            .ok_or("Missing account receipt chain hash".to_string())?,
    )
    .map_err(|err| err.to_string())?;
    let delegate = if let Some(delegate) = account.delegate {
        // TODO(xqft): is there a better way to handle the Result of from_address without if-let?
        Some(CompressedPubKey::from_address(&delegate).map_err(|err| err.to_string())?)
    } else {
        None
    };
    let voting_for = VotingFor::parse_str(
        &account
            .voting_for
            .ok_or("Missing account voting for".to_string())?,
    )
    .map_err(|err| err.to_string())?;
    let timing = Timing::Timed {
        initial_minimum_balance: currency::Balance::from_u64(
            account
                .timing
                .initial_minimum_balance
                .ok_or("Missing account initial minimum balance".to_string())?
                .parse()
                .map_err(|_| "Could not parse account initial minimum balance".to_string())?,
        ),
        cliff_time: currency::Slot::from_u32(
            account
                .timing
                .cliff_time
                .ok_or("Missing account cliff time".to_string())?
                .parse()
                .map_err(|_| "Could not parse account cliff time".to_string())?,
        ),
        cliff_amount: currency::Amount::from_u64(
            account
                .timing
                .cliff_amount
                .ok_or("Missing account cliff amount".to_string())?
                .parse()
                .map_err(|_| "Could not parse account cliff amount".to_string())?,
        ),
        vesting_period: currency::SlotSpan::from_u32(
            account
                .timing
                .vesting_period
                .ok_or("Missing account vesting period".to_string())?
                .parse()
                .map_err(|_| "Could not parse account vesting period".to_string())?,
        ),
        vesting_increment: currency::Amount::from_u64(
            account
                .timing
                .vesting_increment
                .ok_or("Missing account vesting increment".to_string())?
                .parse()
                .map_err(|_| "Could not parse account vesting increment".to_string())?,
        ),
    };
    println!("2");

    // TODO(xqft): implement a proper From trait
    let parse_auth_req = |variant: AccountAuthRequired| -> AuthRequired {
        match variant {
            AccountAuthRequired::None => AuthRequired::None,
            AccountAuthRequired::Either => AuthRequired::Either,
            AccountAuthRequired::Proof => AuthRequired::Proof,
            AccountAuthRequired::Signature => AuthRequired::Signature,
            AccountAuthRequired::Impossible => AuthRequired::Impossible,
            AccountAuthRequired::Other(_) => unreachable!(),
        }
    };

    let permissions = account
        .permissions
        .ok_or("Missing account permissions".to_string())?;
    let permissions = Permissions {
        edit_state: parse_auth_req(permissions.edit_state),
        access: parse_auth_req(permissions.access),
        send: parse_auth_req(permissions.send),
        receive: parse_auth_req(permissions.receive),
        set_delegate: parse_auth_req(permissions.set_delegate),
        set_permissions: parse_auth_req(permissions.set_permissions),
        set_verification_key: mina_tree::SetVerificationKey {
            auth: parse_auth_req(permissions.set_verification_key.auth),
            txn_version: TxnVersion::from_u32(
                permissions
                    .set_verification_key
                    .txn_version
                    .parse()
                    .map_err(|_| "Failed to parse TxnVersion".to_string())?,
            ),
        },
        set_zkapp_uri: parse_auth_req(permissions.set_zkapp_uri),
        edit_action_state: parse_auth_req(permissions.edit_action_state),
        set_token_symbol: parse_auth_req(permissions.set_token_symbol),
        increment_nonce: parse_auth_req(permissions.increment_nonce),
        set_voting_for: parse_auth_req(permissions.set_voting_for),
        set_timing: parse_auth_req(permissions.set_timing),
    };

    Ok(Account {
        public_key,
        token_id,
        token_symbol,
        balance,
        nonce,
        receipt_chain_hash,
        delegate,
        voting_for,
        timing,
        permissions,
        zkapp: None, // TODO(xqft): handle zkapp
    })
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
mod test {
    use super::query_account;

    #[test]
    fn test_query_account() {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(async {
                query_account(
                    "http://5.9.57.89:3085/graphql",
                    "B62qnFCUtCu4bHJZGroNZvmq8ya1E9kAJkQGYnETh9E3CMHV98UvrPZ",
                )
                .await
                .unwrap();
            });
    }
}
