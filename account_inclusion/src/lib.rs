use kimchi::mina_curves::pasta::Fp;
use mina_p2p_messages::v2::hash_with_kimchi;
use mina_tree::MerklePath;
use std::fmt::Write;

/// Based on OpenMina's implementation
/// https://github.com/openmina/openmina/blob/d790af59a8bd815893f7773f659351b79ed87648/ledger/src/account/account.rs#L1444
pub fn verify_merkle_proof(merkle_leaf: Fp, merkle_path: Vec<MerklePath>, merkle_root: Fp) -> bool {
    let mut param = String::with_capacity(16);

    let calculated_root =
        merkle_path
            .iter()
            .enumerate()
            .fold(merkle_leaf, |accum, (depth, path)| {
                let hashes = match path {
                    MerklePath::Left(right) => [accum, *right],
                    MerklePath::Right(left) => [*left, accum],
                };

                param.clear();
                write!(&mut param, "MinaMklTree{:03}", depth).unwrap();

                hash_with_kimchi(param.as_str(), &hashes)
            });

    calculated_root == merkle_root
}

#[cfg(test)]
mod test {
    use core::{
        mina_polling_service::{query_candidate, query_merkle},
        smart_contract_utility::get_tip_state_hash,
        utils::env::EnvironmentVariables,
    };

    use mina_p2p_messages::v2::StateHash;

    use super::*;

    #[test]
    fn test_verify_merkle_proof() {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(async {
                println!("Hello world");
                let EnvironmentVariables {
                    rpc_url,
                    chain,
                    eth_rpc_url,
                    ..
                } = EnvironmentVariables::new().unwrap();

                let state_hash =
                    StateHash::from_fp(Fp::from(query_candidate(&rpc_url).unwrap().0)).to_string();
                let public_key = "B62qoVxygiYzqRCj4taZDbRJGY6xLvuzoiLdY5CpGm7L9Tz5cj2Qr6i";
                let (merkle_root, merkle_leaf, merkle_path) =
                    query_merkle(&rpc_url, &state_hash.to_string(), public_key)
                        .await
                        .unwrap();

                assert!(verify_merkle_proof(merkle_leaf, merkle_path, merkle_root));
            });
    }
}
