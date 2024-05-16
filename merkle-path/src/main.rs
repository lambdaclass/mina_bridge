pub mod account;
pub mod big_int;
pub mod merkle_path;
pub mod merkle_root;

use crate::account::query_account;
use crate::merkle_path::MerkleTree;
use crate::merkle_root::MerkleRoot;
use mina_p2p_messages::v2::MerkleTreeNode;

fn main() {
    let queried_account = query_account("B62qk8PgLSaL6DJKniMXwh6zePZP3q8vRLQDw1prXyu5YqZZMMemSQ2");
    println!("queried_account: {:?}", queried_account);

    let received_merkle_path =
        MerkleTree::query_merkle_path("B62qk8PgLSaL6DJKniMXwh6zePZP3q8vRLQDw1prXyu5YqZZMMemSQ2");

    let root = MerkleRoot::query_merkle_root();
    println!("queried root: {:?}", root);

    let merkle_root = received_merkle_path.get_root();

    println!("computed root: {:?}", merkle_root);

    let received_merkle_path_vec: Vec<MerkleTreeNode> = received_merkle_path.into();
    // TODO:
    // 1. Verify the merkle proof using openmina
    let root = snark::calc_merkle_root_hash(&queried_account, &received_merkle_path_vec);
}
