use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::MinaBaseAccountBinableArgStableV2 as MinaAccount;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use sha3::Digest;

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
    #[serde_as(as = "SolSerialize")]
    pub account_hash: AccountHash,
}

#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct MinaAccountProof {
    /// Merkle path between the leaf hash (account hash) and the merkle root (ledger hash)
    pub merkle_path: Vec<MerkleNode>,
    /// The leaf of the merkle tree.
    pub account: MinaAccount,
}
