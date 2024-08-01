use std::{fmt::Write, str::FromStr};

use kimchi::mina_curves::pasta::Fp;
use mina_p2p_messages::v2::{hash_with_kimchi, LedgerHash};
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
    pub daemon_status: Option<DaemonStatus>,
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
    let query: Query = serde_json::from_str(
        &reqwest::blocking::Client::new()
            .post(rpc_url)
            .header(CONTENT_TYPE, "application/json")
            .body(format!(
                "{{\"query\": \"{{
                    account(publicKey: \\\"{public_key}\\\") {{
                      leafHash
                      merklePath {{
                          left
                          right
                      }}
                    }}
                }}\"}}"
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

/// Based on OpenMina's implementation
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
    use super::*;

    /// Queries the ledger's merkle root. Used for testing.
    fn query_ledgers_merkle_root(rpc_url: &str) -> Result<Fp, String> {
        let query: Query = serde_json::from_str(
            &reqwest::blocking::Client::new()
                .post(rpc_url)
                .header(CONTENT_TYPE, "application/json")
                .body(format!(
                    "{{\"query\": \"{{
                    daemonStatus {{
                        ledgerMerkleRoot
                    }}
                }}\"}}",
                ))
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
    fn test_query_merkle_root() {
        query_ledgers_merkle_root("http://5.9.57.89:3085/graphql").unwrap();
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
