pub mod merkle_root;

use crate::merkle_root::MerkleRoot;

fn main() {
    let received_merkle_root = MerkleRoot::query_merkle_root();
    std::fs::write(
        "../mina_3_0_0_devnet/src/lib/merkle_root_parser/merkle_root.txt",
        received_merkle_root
            .data
            .daemon_status
            .ledger_merkle_root
            .clone(),
    )
    .unwrap();
}
