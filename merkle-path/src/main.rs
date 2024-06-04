pub mod account;
pub mod merkle_path;
pub mod merkle_root;

use crate::merkle_path::MerkleTree;
use crate::merkle_root::MerkleRoot;

static PUBLIC_KEY: &str = "B62qjpfEV5NEK2LMHqD5t7KkEYcZvsqwf7RBz4qz2hXX5vZPDSF7U9s";

fn main() {
    let received_merkle_path = MerkleTree::query_merkle_path(PUBLIC_KEY);

    let root = MerkleRoot::query_merkle_root();
    println!("queried root: {:?}", root);

    //let received_merkle_path_vec: Vec<MerkleTreeNode> = received_merkle_path.into();
}
