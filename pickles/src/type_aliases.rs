use kimchi::{
    mina_curves::pasta::Pallas, poly_commitment::evaluation_proof::OpeningProof,
    proof::ProverProof, verifier_index::VerifierIndex,
};

pub type WrapOpeningProof = OpeningProof<Pallas>;
pub type WrapVerifierIndex = VerifierIndex<Pallas, WrapOpeningProof>;
pub type WrapProverProof = ProverProof<Pallas, WrapOpeningProof>;
