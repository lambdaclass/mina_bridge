pub mod merkle_path;
pub mod merkle_root;

use crate::merkle_path::MerkleTree;

fn main() {
    let received_merkle_path =
        MerkleTree::query_merkle_path("B62qk8PgLSaL6DJKniMXwh6zePZP3q8vRLQDw1prXyu5YqZZMMemSQ2");

    println!("{:?}", received_merkle_path);
    //let merkle_root = received_merkle_path.get_root();

    //println!("merkle root: {}", merkle_root);
}
