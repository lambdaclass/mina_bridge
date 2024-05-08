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
