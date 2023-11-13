use serde_json::Value;
use std::env;
use std::fs;

// Example:
// {"data":{"bestChain":[{"creator":"B62qoA5XwfEVnXbcrzphGH1TVuqxeJ5bhX7vTS3hcxpQFHnStG3MQk9","stateHashField":"24924803968503832121419666918600454255868948649936693214146949523817136720847","protocolState":{"consensusState":{"blockHeight":"303201"}}}]}}%

fn main() {
    let args: Vec<_> = env::args().collect();
    let query = serde_json::from_str::<Value>(&args[1]).unwrap();
    let query = query
        .get("data")
        .and_then(|v| v.get("bestChain"))
        .and_then(|v| v.get(0))
        .unwrap();

    let state = parse_and_serialize_state(query);
    let proof = parse_proof(query);
    fs::write("../eth_verifier/state.mpk", state).unwrap();
    fs::write("proof.txt", proof).unwrap();
}

fn parse_and_serialize_state(query: &Value) -> Vec<u8> {
    let creator = query.get("creator").and_then(Value::as_str).unwrap();
    let hash = query.get("stateHashField").and_then(Value::as_str).unwrap();
    let height = query
        .get("protocolState")
        .and_then(|v| v.get("consensusState"))
        .and_then(|v| v.get("blockHeight"))
        .and_then(Value::as_str)
        .unwrap();

    let data = vec![creator, hash, height];
    rmp_serde::to_vec(&data).unwrap()
}

fn parse_proof(query: &Value) -> String {
    query
        .get("protocolStateProof")
        .and_then(|v| v.get("base64"))
        .and_then(Value::as_str)
        .unwrap()
        .to_string()
}
