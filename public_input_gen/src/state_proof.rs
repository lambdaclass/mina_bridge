use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct StateProof {
    pub proof: Proof,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Proof {
    pub openings: Openings,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Openings {
    pub proof: OpeningProof,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OpeningProof {
    pub z_1: String,
    pub sg: (String, String),
}
