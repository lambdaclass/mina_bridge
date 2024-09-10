use mina_curves::pasta::Fp;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use crate::sol::serialization::SolSerialize;

#[serde_as]
#[derive(Serialize, Deserialize)]
pub enum MerkleNode {
    Left(#[serde_as(as = "o1_utils::serialization::SerdeAs")] Fp),
    Right(#[serde_as(as = "o1_utils::serialization::SerdeAs")] Fp),
}

#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct MinaAccountPubInputs {
    #[serde_as(as = "SolSerialize")]
    pub ledger_hash: Fp,
    pub encoded_account: Vec<u8>,
}

#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct MinaAccountProof {
    /// Merkle path between the leaf hash (account hash) and the merkle root (ledger hash)
    pub merkle_path: Vec<MerkleNode>,
}
