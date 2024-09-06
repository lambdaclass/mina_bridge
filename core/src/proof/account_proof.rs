use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::MinaBaseAccountBinableArgStableV2 as MinaAccount;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use sha3::Digest;

use crate::proof::serialization::EVMSerialize;

#[serde_as]
#[derive(Serialize, Deserialize)]
pub enum MerkleNode {
    Left(#[serde_as(as = "o1_utils::serialization::SerdeAs")] Fp),
    Right(#[serde_as(as = "o1_utils::serialization::SerdeAs")] Fp),
}

#[derive(Serialize, Deserialize)]
pub struct AccountHash(pub [u8; 32]);

impl AccountHash {
    // TODO(xqft): hash a Mina account
    pub fn new(_account: &MinaAccount) -> Self {
        let mut hasher = sha3::Keccak256::new();
        //hasher.update(account);
        Self(hasher.finalize_reset().into())
    }
}

#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct MinaAccountPubInputs {
    #[serde_as(as = "EVMSerialize")]
    pub ledger_hash: Fp,
    #[serde_as(as = "EVMSerialize")]
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
