pub mod merkle_path;
use reqwest::header::CONTENT_TYPE;

use crate::merkle_path::MerkleTree;

fn main() {
    let client = reqwest::blocking::Client::new();
    let res = client
        .post("http://5.9.57.89:3085/graphql")
        .header(CONTENT_TYPE, "application/json")
        .body(
            r#"{"query": "{
            account(publicKey: \"B62qk8PgLSaL6DJKniMXwh6zePZP3q8vRLQDw1prXyu5YqZZMMemSQ2\") {
              leafHash
              merklePath { 
                  left 
                  right
              }
            }
        }"}"#,
        )
        .send()
        .unwrap()
        .text()
        .unwrap();

    let received_merkle_path: MerkleTree = serde_json::from_str(&res).unwrap();
    let merkle_root = received_merkle_path.get_root();

    println!("merkle root: {}", merkle_root);
}
