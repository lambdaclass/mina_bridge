use std::env;

// Example:
// {"data":{"bestChain":[{"creator":"B62qoA5XwfEVnXbcrzphGH1TVuqxeJ5bhX7vTS3hcxpQFHnStG3MQk9","stateHashField":"24924803968503832121419666918600454255868948649936693214146949523817136720847","protocolState":{"consensusState":{"blockHeight":"303201"}}}]}}%

fn main() {
    let args: Vec<_> = env::args().collect();
    let query: serde_json::Value = serde_json::from_str(&args[1]).unwrap();
    let state = query
        .get("data")
        .and_then(|v| v.get("bestChain"))
        .and_then(|v| v.get(0));

    let creator = state
        .and_then(|v| v.get("creator"))
        .unwrap()
        .as_str()
        .unwrap();

    let hash = state
        .and_then(|v| v.get("stateHashField"))
        .unwrap()
        .as_str()
        .unwrap();

    let height = state
        .and_then(|v| v.get("protocolState"))
        .and_then(|v| v.get("consensusState"))
        .and_then(|v| v.get("blockHeight"))
        .unwrap()
        .as_str()
        .unwrap();

    let data = vec![creator, hash, height];
    let rmp = hex::encode(rmp_serde::to_vec(&data).unwrap());

    println!("{}", rmp);
}
