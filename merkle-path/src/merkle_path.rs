use ark_ff::FromBytes as _;
use kimchi::{
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        pasta::fp_kimchi::static_params,
        poseidon::{ArithmeticSponge, Sponge as _},
    },
    o1_utils::FieldHelpers as _,
};
use mina_curves::pasta::Fp;
use num_bigint::BigUint;
use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};
use std::fmt::Write as _;
use std::str::FromStr as _;

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

    pub fn get_root(&self) -> Vec<u8> {
        let input_field = Self::string_to_field(&self.data.account.leaf_hash.clone().unwrap());
        let mut param = String::with_capacity(16);
        let merkle_path_map = self.create_map();

        merkle_path_map
            .iter()
            .enumerate()
            .fold(input_field, |child, (depth, path)| {
                let (direction, split_path) = path.split_at(1);
                let hashes = match direction {
                    "0" => [Self::string_to_field(split_path), child],
                    "1" => [child, Self::string_to_field(split_path)],
                    _ => panic!("Path direction must be 0 or 1 but is {}", direction),
                };

                param.clear();
                write!(&mut param, "MinaMklTree{:03}", depth).unwrap();

                Self::hash_with_kimchi(&param, &hashes)
            })
            .to_bytes()
    }

    fn string_to_field(input: &str) -> Fp {
        Fp::from_biguint(&BigUint::from_str(&input).unwrap()).unwrap()
    }

    fn hash_with_kimchi(param: &str, fields: &[Fp]) -> Fp {
        let mut sponge = ArithmeticSponge::<Fp, PlonkSpongeConstantsKimchi>::new(static_params());

        sponge.absorb(&[Self::param_to_field(param)]);
        sponge.squeeze();

        sponge.absorb(fields);
        sponge.squeeze()
    }

    fn param_to_field_impl(param: &str, default: [u8; 32]) -> Fp {
        let param_bytes = param.as_bytes();
        let len = param_bytes.len();

        let mut fp = default;
        fp[..len].copy_from_slice(param_bytes);

        Fp::read(&fp[..]).expect("fp read failed")
    }

    fn param_to_field(param: &str) -> Fp {
        const DEFAULT: [u8; 32] = [
            b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*',
            b'*', b'*', b'*', b'*', b'*', b'*', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ];

        if param.len() > 20 {
            panic!("must be 20 byte maximum");
        }

        Self::param_to_field_impl(param, DEFAULT)
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

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleLeaf {
    pub left: Option<String>,
    pub right: Option<String>,
}

#[cfg(test)]
mod test {

    use super::{MerkleLeaf, MerkleTree};
    use ark_ff::FromBytes as _;
    use kimchi::{
        mina_poseidon::{
            constants::PlonkSpongeConstantsKimchi,
            pasta::fp_kimchi::static_params,
            poseidon::{ArithmeticSponge, Sponge as _},
        },
        o1_utils::FieldHelpers as _,
    };
    use mina_curves::pasta::Fp;
    use num_bigint::BigUint;
    use std::str::FromStr as _;

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

    #[test]
    fn test_fp() {
        use kimchi::o1_utils::FieldHelpers;
        use mina_curves::pasta::Fp;

        let f = "8186407070323331717412068877244574160296972200577316395640080416951883426150";
        let fp = Fp::from_biguint(&BigUint::from_str(&f).unwrap());

        println!("{:?}", fp);
    }

    #[test]
    fn test_hash() {
        let serialized_merkle_path = r#"{
            "data": {
              "account": {
                "leafHash": "8186407070323331717412068877244574160296972200577316395640080416951883426150",
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
        let merkle_path: MerkleTree = serde_json::from_str(&serialized_merkle_path).unwrap();
        let merkle_root = merkle_path.get_root();

        // TODO: compare merkle_root with expected value
    }
}
