use binprot_derive::BinProtRead;
use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};

use crate::big_int::BigInt;

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

#[derive(BinProtRead)]
pub struct LedgerHash(pub BigInt);

impl MerkleRoot {
    pub fn query_merkle_root() -> Vec<u8> {
        let body = format!(
            "{{\"query\": \"{{
                daemonStatus {{
                  ledgerMerkleRoot
                }}
              }}\"}}"
        );
        let client = reqwest::blocking::Client::new();
        let res = client
            .post("http://5.9.57.89:3085/graphql")
            .header(CONTENT_TYPE, "application/json")
            .body(body)
            .send()
            .unwrap()
            .text()
            .unwrap();
        let aux: Self = serde_json::from_str(&res).unwrap();
        let ledger_hash_checksum = 0x05;
        bs58::decode(&aux.data.daemon_status.ledger_merkle_root)
            .with_check(Some(ledger_hash_checksum))
            .into_vec()
            .unwrap()
    }
}
