use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::{
    circuits::lookup::index::LookupSelectors, proof::{PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof}, verifier_index::{LookupVerifierIndex, VerifierIndex}
};
use poly_commitment::{pairing_proof::PairingProof, PolyComm};

pub type ScalarField = ark_bn254::Fr;
pub type BaseField = ark_bn254::Fq;

pub type G1Point = GroupAffine<ark_bn254::g1::Parameters>;

pub type BN254PolyComm = PolyComm<G1Point>;

pub type BN254PairingProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
pub type BN254ProofEvaluations = ProofEvaluations<PointEvaluations<Vec<ScalarField>>>;
pub type BN254ProverCommitments = ProverCommitments<G1Point>;
pub type BN254ProverProof = ProverProof<G1Point, BN254PairingProof>;

pub type BN254VerifierIndex = VerifierIndex<G1Point, BN254PairingProof>;
pub type BN254LookupVerifierIndex = LookupVerifierIndex<G1Point>;
pub type BN254LookupSelectors = LookupSelectors<BN254PolyComm>;
