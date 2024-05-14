use std::str::FromStr as _;

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
use serde::{Deserialize, Serialize};
use std::fmt::Write as _;

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MerkleRoot {
    pub data: Data,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Data {
    pub daemon_status: LedgerMerkleRoot,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LedgerMerkleRoot {
    pub ledger_merkle_root: String,
}
