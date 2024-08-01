use std::{fmt::Write, str::FromStr};

use base64::{prelude::BASE64_STANDARD, Engine};
use kimchi::mina_curves::pasta::Fp;
use log::debug;
use mina_p2p_messages::{
    binprot::BinProtRead,
    v2::{hash_with_kimchi, MinaStateProtocolStateValueStableV2, StateHash},
};
use mina_tree::MerklePath;
use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Query {
    pub data: Data,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Data {
    pub account: Option<Account>,
    #[cfg(test)]
    pub daemon_status: Option<DaemonStatus>,
    pub protocol_state: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub leaf_hash: String,
    pub merkle_path: Vec<MerkleLeaf>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MerkleLeaf {
    pub left: Option<String>,
    pub right: Option<String>,
}

#[cfg(test)]
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct DaemonStatus {
    pub ledger_merkle_root: String,
}

/// Queries the merkle path and leaf hash from the GraphQL endpoint.
pub fn query_leaf_and_merkle_path(
    rpc_url: &str,
    public_key: &str,
) -> Result<(Fp, Vec<MerklePath>), String> {
    // TODO(xqft): we can't trust the Mina node to provide us
    // the correct leaf hash, we should add a check or directly
    // hash the account information to get the leaf.

    debug!("Querying merkle leaf and path of public key {}", public_key);
    let query: Query = serde_json::from_str(
        &reqwest::blocking::Client::new()
            .post(rpc_url)
            .header(CONTENT_TYPE, "application/json")
            .body(format!(
                r#"{{
                    "query": "{{
                        account(publicKey: \"{public_key}\") {{
                            leafHash
                            merklePath {{
                                left
                                right
                            }}
                        }}
                    }}"
                }}"#,
            ))
            .send()
            .map_err(|err| format!("Error making request {err}"))?
            .text()
            .map_err(|err| format!("Error getting text {err}"))?,
    )
    .map_err(|err| format!("Error converting to json {err}"))?;

    let account = query
        .data
        .account
        .ok_or("Error getting account data".to_string())?;

    let leaf_hash = Fp::from_str(&account.leaf_hash)
        .map_err(|_| "Error deserializing leaf hash".to_string())?;
    let merkle_path = account
        .merkle_path
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

    Ok((leaf_hash, merkle_path))
}

/// Queries the ledger's merkle root from a state object, via its state hash.
pub fn query_merkle_root(rpc_url: &str, state_hash: Fp) -> Result<Fp, String> {
    let state_hash = StateHash::from_fp(state_hash).to_string();
    debug!("Querying merkle root of encoded state hash {}", state_hash);

    let query: Query = serde_json::from_str(
        &reqwest::blocking::Client::new()
            .post(rpc_url)
            .header(CONTENT_TYPE, "application/json")
            .body(format!(
                r#"{{
                    "query": "{{
                        protocolState(encoding: BASE64, stateHash: \"{state_hash}\") {{
                            leafHash
                            merklePath {{
                                left
                                right
                            }}
                        }}
                    }}"
                }}"#,
            ))
            .send()
            .map_err(|err| format!("Error making request {err}"))?
            .text()
            .map_err(|err| format!("Error getting text {err}"))?,
    )
    .map_err(|err| format!("Error converting to json {err}"))?;

    let protocol_state_base64 = query
        .data
        .protocol_state
        .ok_or("Error getting protocol state".to_string())?;
    let protocol_state_binprot = BASE64_STANDARD
        .decode(protocol_state_base64)
        .map_err(|err| err.to_string())?;
    let protocol_state =
        MinaStateProtocolStateValueStableV2::binprot_read(&mut protocol_state_binprot.as_slice())
            .map_err(|err| err.to_string())?;

    Ok(protocol_state
        .body
        .blockchain_state
        .staged_ledger_hash
        .non_snark
        .ledger_hash
        .0
        .clone()
        .into())
}

/// Based on OpenMina's implementation
/// https://github.com/openmina/openmina/blob/d790af59a8bd815893f7773f659351b79ed87648/ledger/src/account/account.rs#L1444
pub fn verify_merkle_proof(leaf_hash: Fp, merkle_path: Vec<MerklePath>, merkle_root: Fp) -> bool {
    let mut param = String::with_capacity(16);

    let calculated_root = merkle_path
        .iter()
        .enumerate()
        .fold(leaf_hash, |accum, (depth, path)| {
            let hashes = match path {
                MerklePath::Left(right) => [accum, *right],
                MerklePath::Right(left) => [*left, accum],
            };

            param.clear();
            write!(&mut param, "MinaMklTree{:03}", depth).unwrap();

            hash_with_kimchi(param.as_str(), &hashes)
        });

    calculated_root == merkle_root
}

#[cfg(test)]
mod test {
    use mina_p2p_messages::v2::LedgerHash;

    use super::*;

    /// Queries the ledger's merkle root. Used for testing.
    fn query_ledgers_merkle_root(rpc_url: &str) -> Result<Fp, String> {
        let query: Query = serde_json::from_str(
            &reqwest::blocking::Client::new()
                .post(rpc_url)
                .header(CONTENT_TYPE, "application/json")
                .body(
                    r#"{
                    "query": "{
                        daemonStatus {
                            ledgerMerkleRoot
                        }
                    }"
                }"#,
                )
                .send()
                .map_err(|err| format!("Error making request {err}"))?
                .text()
                .map_err(|err| format!("Error getting text {err}"))?,
        )
        .map_err(|err| format!("Error converting to json {err}"))?;

        Ok(LedgerHash::from_str(
            &query
                .data
                .daemon_status
                .ok_or("Error getting daemon status".to_string())?
                .ledger_merkle_root,
        )
        .map_err(|_| "Error deserializing leaf hash".to_string())?
        .0
        .clone()
        .into())
    }

    #[test]
    fn test_merkle_leaf() {
        let serialized = r#"{
            "right": "42",
            "left": null
          }"#;
        let deserialized: MerkleLeaf = serde_json::from_str(serialized).unwrap();

        assert_eq!(deserialized.left, None);
    }

    #[test]
    fn test_merkle_path() {
        let serialized = r#"{
            "data": {
              "account": {
                "leafHash": "25269606294916619424328783876704640983264873133815222226208603489064938585963",
                "merklePath": [
                  {
                    "left": null,
                    "right": "25269606294916619424328783876704640983264873133815222226208603489064938585963"
                  },
                  {
                    "left": "8196401609013649445499057870676218044178796697776855327762810874439081359829",
                    "right": null
                  }
                  ]
                }
              }
            }"#;
        serde_json::from_str::<Query>(serialized).unwrap();
    }

    #[test]
    fn test_query_leaf_and_merkle_path() {
        query_leaf_and_merkle_path(
            "http://5.9.57.89:3085/graphql",
            "B62qoVxygiYzqRCj4taZDbRJGY6xLvuzoiLdY5CpGm7L9Tz5cj2Qr6i",
        )
        .unwrap();
    }

    #[test]
    fn test_query_ledgers_merkle_root() {
        query_ledgers_merkle_root("http://5.9.57.89:3085/graphql").unwrap();
    }

    #[test]
    fn test_query_merkle_root() {
        let state_hash =
            StateHash::from_str("3NKE3oYnEwSFcuEXWCz1abNLeTgY8BGEvPs1KWPHyj81jmgdojsT")
                .unwrap()
                .to_fp()
                .unwrap();
        let staged_ledger_hash =
            query_merkle_root("http://5.9.57.89:3085/graphql", state_hash).unwrap();
        let ledger_merkle_root =
            LedgerHash::from_str("jxBZvRKv9aCVEDn7Dd48aWDruHhVkcW1vmburY4gbxCDVEZzecL")
                .unwrap()
                .to_fp()
                .unwrap();

        assert_eq!(staged_ledger_hash, ledger_merkle_root);
    }

    #[test]
    fn test_verify_merkle_proof() {
        let (leaf_hash, merkle_path) = query_leaf_and_merkle_path(
            "http://5.9.57.89:3085/graphql",
            "B62qoVxygiYzqRCj4taZDbRJGY6xLvuzoiLdY5CpGm7L9Tz5cj2Qr6i",
        )
        .unwrap();

        let merkle_root = query_ledgers_merkle_root("http://5.9.57.89:3085/graphql").unwrap();

        assert!(verify_merkle_proof(leaf_hash, merkle_path, merkle_root));
    }
}
