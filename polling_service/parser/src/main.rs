use parser::fetch_mina_state;
use std::env;

fn main() -> Result<(), String> {
    let args: Vec<_> = env::args().collect();
    let mina_rpc_url = &args[1];

    fetch_mina_state(mina_rpc_url)
}
