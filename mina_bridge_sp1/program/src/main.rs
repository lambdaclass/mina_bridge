//! A simple program to be proven inside the zkVM.

#![no_main]

use kimchi::{
    mina_curves::pasta::Vesta,
    poly_commitment::{evaluation_proof::OpeningProof, srs::SRS},
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
    let mut verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    let srs = sp1_zkvm::io::read::<SRS<Curve>>();

    let result = kimchi_verify(&proof, &mut verifier_index, srs);
    sp1_zkvm::io::commit(&result);
}
