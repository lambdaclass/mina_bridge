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

#[allow(clippy::module_name_repetitions)]
#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LedgerMerkleRoot {
    pub ledger_merkle_root: String,
}

impl MerkleRoot {
    /// Query the ledger merkle root from the GraphQL endpoint.
    ///
    /// # Errors
    ///
    /// If the request fails, an error will be returned.
    pub fn query_merkle_root() -> Result<Self, String> {
        let body = "{{\"query\": \"{{
                daemonStatus {{
                  ledgerMerkleRoot
                }}
              }}\"}}"
            .to_owned();
        let client = reqwest::blocking::Client::new();
        let res = client
            .post("http://5.9.57.89:3085/graphql")
            .header(CONTENT_TYPE, "application/json")
            .body(body)
            .send()
            .map_err(|err| err.to_string())?
            .text()
            .map_err(|err| err.to_string())?;
        serde_json::from_str(&res).map_err(|err| err.to_string())
    }
}
