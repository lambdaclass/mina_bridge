use reqwest::header::CONTENT_TYPE;
use serde::{Deserialize, Serialize};

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

impl MerkleRoot {
    pub fn query_merkle_root() -> Self {
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
        serde_json::from_str(&res).unwrap()
    }
}
