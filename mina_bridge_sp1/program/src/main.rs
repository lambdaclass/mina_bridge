//! A simple program to be proven inside the zkVM.

#![no_main]

use kimchi::{
    groupmap::GroupMap,
    mina_curves::pasta::Vesta,
    poly_commitment::{commitment::CommitmentCurve, evaluation_proof::OpeningProof},
    proof::ProverProof,
    verifier_index::VerifierIndex,
};
use kimchi_verifier_ffi::kimchi_verify;

sp1_zkvm::entrypoint!(main);

type Curve = Vesta;
type KimchiOpeningProof = OpeningProof<Curve>;
type KimchiProof = ProverProof<Curve, KimchiOpeningProof>;
type KimchiVerifierIndex = VerifierIndex<Curve, KimchiOpeningProof>;

pub fn main() {
    let proof = sp1_zkvm::io::read::<KimchiProof>();
    let verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    let group_map = <Curve as CommitmentCurve>::Map::setup();

    let result = kimchi_verify(proof, verifier_index, group_map);
    sp1_zkvm::io::commit(&result);
}
