use kimchi::{
    mina_curves::pasta::Fp,
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        pasta::fp_kimchi::static_params,
        poseidon::{ArithmeticSponge, Sponge},
    },
    o1_utils::FieldHelpers,
};
use std::fmt::Write;

#[derive(PartialEq, Eq)]
pub enum MerkleNode {
    Left(Fp),
    Right(Fp),
}

impl MerkleNode {
    pub fn hash(&self) -> &Fp {
        match self {
            MerkleNode::Left(h) => h,
            MerkleNode::Right(h) => h,
        }
    }

    pub fn from_bytes(mut bytes: Vec<u8>) -> Result<Self, String> {
        let left_right_flag = bytes
            .pop()
            .ok_or("Missing bytes from serialized merkle node".to_string())?;
        let hash = Fp::from_bytes(&bytes).map_err(|err| err.to_string())?;
        match left_right_flag {
            0 => Ok(MerkleNode::Left(hash)),
            1 => Ok(MerkleNode::Right(hash)),
            _ => Err("Invalid left-right flag of serialized merkle node".to_string()),
        }
    }
}

/// Based on OpenMina's implementation
/// https://github.com/openmina/openmina/blob/d790af59a8bd815893f7773f659351b79ed87648/ledger/src/account/account.rs#L1444
pub fn verify_merkle_proof(leaf_hash: Fp, merkle_path: Vec<MerkleNode>, merkle_root: Fp) -> bool {
    let mut param = String::with_capacity(16);

    let calculated_root = merkle_path
        .iter()
        .enumerate()
        .fold(leaf_hash, |accum, (depth, path)| {
            let hashes = match path {
                MerkleNode::Left(right) => [accum, *right],
                MerkleNode::Right(left) => [*left, accum],
            };

            param.clear();
            write!(&mut param, "MinaMklTree{:03}", depth).unwrap();

            hash_with_kimchi(param.as_str(), &hashes)
        });

    calculated_root == merkle_root
}

pub fn hash_with_kimchi(param: &str, fields: &[Fp]) -> Fp {
    let mut sponge = ArithmeticSponge::<Fp, PlonkSpongeConstantsKimchi>::new(static_params());

    sponge.absorb(&[param_to_field(param)]);
    sponge.squeeze();

    sponge.absorb(fields);
    sponge.squeeze()
}

fn param_to_field_impl(param: &str, default: [u8; 32]) -> Fp {
    let param_bytes = param.as_bytes();
    let len = param_bytes.len();

    let mut fp = default;
    fp[..len].copy_from_slice(param_bytes);

    Fp::from_bytes(&fp[..]).expect("fp read failed")
}

pub fn param_to_field(param: &str) -> Fp {
    const DEFAULT: [u8; 32] = [
        b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*', b'*',
        b'*', b'*', b'*', b'*', b'*', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    if param.len() > 20 {
        panic!("must be 20 byte maximum");
    }

    param_to_field_impl(param, DEFAULT)
}
