use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::proof::{PointEvaluations, ProofEvaluations, ProverProof};
use poly_commitment::pairing_proof::PairingProof;

pub type ScalarField = ark_bn254::Fr;
pub type BaseField = ark_bn254::Fq;

pub type G1Point = GroupAffine<ark_bn254::g1::Parameters>;

pub type BN254PairingProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
pub type BN254ProofEvaluations = ProofEvaluations<PointEvaluations<Vec<ScalarField>>>;
pub type BN254ProverProof = ProverProof<G1Point, BN254PairingProof>;
