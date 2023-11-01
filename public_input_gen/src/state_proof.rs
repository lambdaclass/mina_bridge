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
    pub z_1: String,
    pub sg: (String, String),
}

impl Default for OpeningProof {
    fn default() -> Self {
        Self {
            z_1: "0x75d0c77584add41f17def4d95a514fc581f2645991898494d13f23379caab809".to_string(),
            sg: (
                "0x940c1562a65e01fda0c7bca7058ad2746c84f0494c98b24d45295850096c581b".to_string(),
                "0xd5a8fcddba00b27b0baed3eae659f308aadf76bbe8a5ef110a4381aa2e27cb1e".to_string(),
            ),
        }
    }
}
