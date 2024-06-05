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
    /// Queries the ledger merkle root from the GraphQL endpoint.
    ///
    /// # Errors
    ///
    /// Returns a string slice with an error message if the request cannot be made,
    /// the response cannot be converted to JSON,
    /// or the base 58 decoding fails.
    pub fn query_merkle_root() -> Result<Vec<u8>, String> {
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
            .map_err(|err| format!("Error making request {err}"))?
            .text()
            .map_err(|err| format!("Error getting text {err}"))?;
        let aux: Self =
            serde_json::from_str(&res).map_err(|err| format!("Error converting to json {err}"))?;
        let ledger_hash_checksum = 0x05;
        bs58::decode(&aux.data.daemon_status.ledger_merkle_root)
            .with_check(Some(ledger_hash_checksum))
            .into_vec()
            .map_err(|err| format!("Error in base 58 decode {err}"))
    }
}
