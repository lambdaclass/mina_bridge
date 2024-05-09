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
                (Some(left), None) => left.to_owned(),
                (None, Some(right)) => right.to_owned(),
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
    use super::{MerkleLeaf, MerkleTree};
    use base58::*;

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
        use pasta_curves::Fp;

        let f = "0x8186407070323331717412068877244574160296972200577316395640080416951883426150";
        //let hex_string = hex::encode(f);
        //println!("hex_string: {:?}", hex_string);
        let deserialized: Fp = serde_json::from_str(&f).unwrap();

        println!("{:?}", deserialized);
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
