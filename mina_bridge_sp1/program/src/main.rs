//! A simple program to be proven inside the zkVM.

#![no_main]

use std::{collections::HashMap, sync::Arc};

use kimchi::{
    mina_curves::pasta::Vesta,
    poly_commitment::{evaluation_proof::OpeningProof, srs::SRS, PolyComm},
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
    println!("cycle-tracker-start: read_data");
    let proof = sp1_zkvm::io::read::<KimchiProof>();
    let mut verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    let mut srs = sp1_zkvm::io::read::<SRS<Curve>>();
    let lagrange_bases = sp1_zkvm::io::read::<HashMap<usize, Vec<PolyComm<Curve>>>>();
    println!("cycle-tracker-end: read_data");

    println!("cycle-tracker-start: lagrange_bases");
    srs.lagrange_bases = lagrange_bases;
    println!("cycle-tracker-end: lagrange_bases");

    println!("cycle-tracker-start: srs");
    verifier_index.srs = Arc::new(srs);
    println!("cycle-tracker-end: srs");

    println!("cycle-tracker-start: verify");
    let result = kimchi_verify(&proof, &verifier_index);
    println!("cycle-tracker-end: verify");
    sp1_zkvm::io::commit(&result);
}
