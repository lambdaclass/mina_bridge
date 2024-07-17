use serde_json::Value;
use std::env;
use std::fs;

fn main() {
    let args: Vec<_> = env::args().collect();
    let query = serde_json::from_str::<Value>(&args[1]).unwrap();
    let query = query
        .get("data")
        .and_then(|v| v.get("bestChain"))
        .and_then(|v| v.get(0))
        .unwrap();

    let state = parse_state_hash(query);
    let proof = parse_proof(query);
    fs::write("../state_hash.txt", state).unwrap();
    fs::write("../state_proof.txt", proof).unwrap();
}

fn parse_state_hash(query: &Value) -> String {
    query
        .get("protocolState")
        .and_then(|v| v.get("previousStateHash"))
        .and_then(Value::as_str)
        .unwrap()
        .to_string()
}

fn parse_proof(query: &Value) -> String {
    query
        .get("protocolStateProof")
        .and_then(|v| v.get("base64"))
        .and_then(Value::as_str)
        .unwrap()
        .to_string()
}
