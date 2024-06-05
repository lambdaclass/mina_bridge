pub mod merkle_root;

use crate::merkle_root::MerkleRoot;

pub fn parse_merkle_root(output_path: &str) {
    let received_merkle_root = MerkleRoot::query_merkle_root();
    std::fs::write(
        output_path,
        received_merkle_root
            .data
            .daemon_status
            .ledger_merkle_root
            .clone(),
    )
    .unwrap();
}
