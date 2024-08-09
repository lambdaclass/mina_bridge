#![no_main]
sp1_zkvm::entrypoint!(main);

use account_inclusion::{verify_merkle_proof, MerkleNode};
use kimchi::{mina_curves::pasta::Fp, o1_utils::FieldHelpers};

pub fn main() {
    let leaf_hash_bytes = sp1_zkvm::io::read_vec();
    sp1_zkvm::io::commit_slice(&leaf_hash_bytes);
    let leaf_hash = Fp::from_bytes(&leaf_hash_bytes).unwrap();

    let merkle_root_bytes = sp1_zkvm::io::read_vec();
    sp1_zkvm::io::commit_slice(&merkle_root_bytes);
    let merkle_root = Fp::from_bytes(&merkle_root_bytes).unwrap();

    let merkle_tree_depth: usize = sp1_zkvm::io::read();
    sp1_zkvm::io::commit(&merkle_tree_depth);

    let mut merkle_path_bytes = Vec::with_capacity(merkle_tree_depth);
    for _ in 0..merkle_tree_depth {
        let bytes = sp1_zkvm::io::read_vec();
        sp1_zkvm::io::commit_slice(&bytes);
        merkle_path_bytes.push(bytes);
    }
    let merkle_path: Vec<_> = merkle_path_bytes
        .into_iter()
        .map(|node_bytes| MerkleNode::from_bytes(node_bytes).unwrap())
        .collect();

    let result = verify_merkle_proof(leaf_hash, merkle_path, merkle_root);

    sp1_zkvm::io::commit(&result);
}
