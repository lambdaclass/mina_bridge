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
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Data {
    pub account: Account,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub merkle_path: Vec<MerkleLeaf>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleLeaf {
    pub left: Option<String>,
    pub right: Option<String>,
}

mod test {
    use std::str::FromStr;

    use super::{MerkleLeaf, MerkleTree};
    use ark_ff::BigInteger;
    use base58::*;
    use num_bigint::BigUint;
    use pasta_curves::group::ff::PrimeField;

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
        use generic_array::typenum::U2;
        use neptune::poseidon::Poseidon;
        use neptune::poseidon::PoseidonConstants;
        use pasta_curves::Fp;

        let preimage_set_length = 1;
        let constants: PoseidonConstants<Fp, U2> =
            PoseidonConstants::new_constant_length(preimage_set_length);

        /*
        let mut poseidon = Poseidon::<Fp, U2>::new_with_preimage(&preimage, &constants);
        let pos = poseidon
            .input(Fp::from(u64::MAX))
            .expect("can't add one more element");
        let digest = poseidon.hash();

        println!("pos: {:?}", pos);
        println!("digest: {:?}", digest);
        */
    }
}
