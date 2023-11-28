use serde::{Deserialize, Serialize};

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct StateProof {
    pub proof: Proof,
}

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct Proof {
    pub openings: Openings,
}

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct Openings {
    pub proof: OpeningProof,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OpeningProof {
    pub lr: Vec<((String, String), (String, String))>,
    pub z_1: String,
    pub z_2: String,
    pub delta: (String, String),
    pub sg: (String, String),
}

impl Default for OpeningProof {
    fn default() -> Self {
        Self {
            lr: vec![(
                (
                    "0xd4ccf32c7b4f0161d4e8f4a50292bca317457ff0bbf1abbc38dcc1b8be146802"
                        .to_string(),
                    "0x0ba37fcfe065248daf83409ecc424ee1aae8c1cc77fdad30b5513d7d95455120"
                        .to_string(),
                ),
                (
                    "0x779b9261b5cfba8a1263e45c396e8f9212dfe62f0a671d594b44dc1c591de931"
                        .to_string(),
                    "0xb8cb94d330a60b2034902af0c0562523ef07c12c327b5e3b0e04a9c3107a662e"
                        .to_string(),
                ),
            )],
            z_1: "0x75d0c77584add41f17def4d95a514fc581f2645991898494d13f23379caab809".to_string(),
            z_2: "0xa328bf7bd8716b28e39e3aa92c1110769aac53ab8e14fa83a55eabdb9c4b993b".to_string(),
            delta: (
                "0x60995d9483eb795d0eef1d54fb3fca3e63c7e1b9280d5a43d09f8621e3fb120f".to_string(),
                "0xdc67524bf496bc81d0e8875b439c6f42b1963cb384c03d025f2dfbde23ccd31b".to_string(),
            ),
            sg: (
                "0x940c1562a65e01fda0c7bca7058ad2746c84f0494c98b24d45295850096c581b".to_string(),
                "0xd5a8fcddba00b27b0baed3eae659f308aadf76bbe8a5ef110a4381aa2e27cb1e".to_string(),
            ),
        }
    }
}
