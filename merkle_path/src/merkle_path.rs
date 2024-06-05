use crate::serialize::EVMSerializable;
use ark_serialize::CanonicalSerialize;
use mina_hasher::Fp;
use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleTree {
    pub data: Data,
}

impl MerkleTree {
    #[must_use]
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

    /// Queries the merkle path from the GraphQL endpoint.
    ///
    /// # Arguments
    ///
    /// * `public_key` - A string slice that holds the public key.
    ///
    /// # Errors
    ///
    /// Returns a string slice with an error message if the request cannot be made,
    /// or the response cannot be converted to JSON.
    pub fn query_merkle_path(public_key: &str) -> Result<Self, String> {
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
            .map_err(|err| format!("Error making request {err}"))?
            .text()
            .map_err(|err| format!("Error getting text {err}"))?;
        serde_json::from_str(&res).map_err(|err| format!("Error converting to json {err}"))
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

fn from_str(s: &str) -> Result<Fp, ()> {
    if s.is_empty() {
        return Err(());
    }

    if s == "0" {
        return Ok(Fp::from(0u8));
    }

    let mut res = Fp::from(0u8);

    let ten = Fp::from(10u8);

    let mut first_digit = true;

    for c in s.chars() {
        match c.to_digit(10) {
            Some(c) => {
                if first_digit {
                    if c == 0 {
                        return Err(());
                    }

                    first_digit = false;
                }

                res *= &ten;
                let digit = Fp::from(u64::from(c));
                res += &digit;
            }
            None => {
                return Err(());
            }
        }
    }
    Ok(res)
    //if res.0 > ark_ff::FpParameters::MODULUS {
    //    Err(())
    //} else {
    //    Ok(res)
    //}
}

fn to_bytes(f: &Fp) -> Vec<u8> {
    let mut bytes: Vec<u8> = vec![];
    f.serialize(&mut bytes).expect("Failed to serialize field");

    bytes.into_iter().rev().collect()
}

impl EVMSerializable for Vec<MerkleLeaf> {
    fn to_bytes(self) -> Vec<u8> {
        let mut ret = Vec::new();
        for leaf in self {
            match (leaf.left, leaf.right) {
                (Some(left), None) => {
                    let f = from_str(&left).unwrap();
                    let bytes = to_bytes(&f);
                    let padding_count = 32 - bytes.len();
                    ret.extend(std::iter::repeat(0_u8).take(padding_count));
                    for byte in bytes {
                        ret.push(byte);
                    }
                    ret.extend(std::iter::repeat(0_u8).take(32));
                }
                (None, Some(right)) => {
                    let f = from_str(&right).unwrap();
                    let bytes = to_bytes(&f);
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

        println!("{ret_to_bytes:?}");
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
        println!("{flatten:?}");
    }
}