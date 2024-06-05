use crate::{field, serialize::EVMSerializable};
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
pub struct Data {
    pub account: Account,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub leaf_hash: Option<String>,
    pub merkle_path: Vec<MerkleLeaf>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MerkleLeaf {
    pub left: Option<String>,
    pub right: Option<String>,
}

impl EVMSerializable for Vec<MerkleLeaf> {
    fn to_bytes(self) -> Vec<u8> {
        let mut ret = Vec::new();
        for leaf in self {
            match (leaf.left, leaf.right) {
                (Some(left), None) => {
                    let f = field::from_str(&left).unwrap();
                    let bytes = field::to_bytes(&f);
                    let padding_count = 32 - bytes.len();
                    ret.extend(std::iter::repeat(0_u8).take(padding_count));
                    for byte in bytes {
                        ret.push(byte);
                    }
                    ret.extend(std::iter::repeat(0_u8).take(32));
                }
                (None, Some(right)) => {
                    let f = field::from_str(&right).unwrap();
                    let bytes = field::to_bytes(&f);
                    let padding_count = 32 - bytes.len();
                    ret.extend(std::iter::repeat(0_u8).take(padding_count));
                    for byte in bytes {
                        ret.push(byte);
                    }
                    ret.extend(std::iter::repeat(0_u8).take(31));
                    ret.push(0b1);
                }
                _ => unreachable!(),
            }
        }
        ret
    }
}

#[cfg(test)]
mod test {
    use crate::merkle_path::MerkleLeaf;
    use crate::serialize::EVMSerializable;
    use crate::MerkleTree;

    #[test]
    fn test_merkle_leaf() {
        let serialized = r#"{
            "right": "42",
            "left": null
          }"#;
        let deserialized: MerkleLeaf = serde_json::from_str(serialized).unwrap();

        let v = vec![deserialized.clone()];
        let ret_to_bytes = v.to_bytes();

        println!("{:?}", ret_to_bytes);
        assert_eq!(deserialized.left, None);
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
        let deserialized: MerkleTree = serde_json::from_str(serialized).unwrap();
        let flatten = deserialized.create_map();
        println!("{:?}", flatten);
    }
}
