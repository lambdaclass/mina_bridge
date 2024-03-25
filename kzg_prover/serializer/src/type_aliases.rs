use ark_ec::short_weierstrass_jacobian::GroupAffine;
use poly_commitment::pairing_proof::PairingProof;

pub type ScalarField = ark_bn254::Fr;
pub type BN254PairingProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
pub type G1Point = GroupAffine<ark_bn254::g1::Parameters>;
pub type BaseField = ark_bn254::Fq;
