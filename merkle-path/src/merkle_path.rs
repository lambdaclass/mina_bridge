use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleTree {
    pub data: Data,
}

impl MerkleTree {
    pub fn create_map(&self) -> Vec<String> {
        self.data
            .account
            .merkle_path
            .iter()
            .map(|leaf| match (&leaf.left, &leaf.right) {
                // 0 if left, 1 if right
                (Some(left), None) => format!("{}{}", "0", left.to_owned()),
                (None, Some(right)) => format!("{}{}", "1", right.to_owned()),
                _ => unreachable!(),
            })
            .collect()
    }

    pub fn query_merkle_path(public_key: &str) -> Self {
        let body = format!(
            "{{\"query\": \"{{
            daemonStatus {{
              ledgerMerkleRoot
            }}
            account(publicKey: \\\"{public_key}\\\") {{
              leafHash
              merklePath {{
                  left 
                  right
              }}
            }}
        }}\"}}"
        );
        let client = reqwest::blocking::Client::new();
        let res = client
            .post("http://5.9.57.89:3085/graphql")
            .header(CONTENT_TYPE, "application/json")
            .body(body)
            .send()
            .unwrap()
            .text()
            .unwrap();
        serde_json::from_str(&res).unwrap()
    }
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Data {
    pub daemon_status: DaemonStatus,
    pub account: Account,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct DaemonStatus {
    pub ledger_merkle_root: String,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub leaf_hash: Option<String>,
    pub merkle_path: Vec<MerkleLeaf>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleLeaf {
    pub left: Option<String>,
    pub right: Option<String>,
}

#[cfg(test)]
mod test {

    use super::{MerkleLeaf, MerkleTree};

    #[test]
    fn test_merkle_leaf() {
        let serialized = r#"{
            "left": "8196401609013649445499057870676218044178796697776855327762810874439081359829",
            "right": null
          }"#;
        let deserialized: MerkleLeaf = serde_json::from_str(&serialized).unwrap();

        assert_eq!(deserialized.right, None);
    }

    #[test]
    fn test_merkle_path() {
        let serialized = r#"{
            "data": {
              "account": {
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
        let deserialized: MerkleTree = serde_json::from_str(&serialized).unwrap();
        let flatten = deserialized.create_map();
        println!("{:?}", flatten);
    }
}
