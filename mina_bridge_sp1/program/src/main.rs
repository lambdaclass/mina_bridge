//! A simple program to be proven inside the zkVM.

#![no_main]

use std::{collections::HashMap, sync::Arc};

use kimchi::{
    mina_curves::pasta::Vesta, poly_commitment::{evaluation_proof::OpeningProof, srs::SRS, PolyComm}, precomputed_srs, proof::ProverProof, verifier_index::VerifierIndex
};
use kimchi_verifier_ffi::kimchi_verify;

sp1_zkvm::entrypoint!(main);

type Curve = Vesta;
type KimchiOpeningProof = OpeningProof<Curve>;
type KimchiProof = ProverProof<Curve, KimchiOpeningProof>;
type KimchiVerifierIndex = VerifierIndex<Curve, KimchiOpeningProof>;
type KimchiSRS = SRS<Curve>;
type KimchiLagrangeBases = HashMap<usize, Vec<PolyComm<Curve>>>;

pub fn main() {
    println!("cycle-tracker-start: deserialize data");

    println!("cycle-tracker-start: deserialize proof");
    let proof = sp1_zkvm::io::read::<KimchiProof>();
    println!("cycle-tracker-end: deserialize proof");

    println!("cycle-tracker-start: deserialize verifier index");
    let mut verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    println!("cycle-tracker-end: deserialize verifier index");

    println!("cycle-tracker-start: load precomp srs");
    let srs = precomputed_srs::get_srs::<Curve>();
    println!("cycle-tracker-end: load precomp srs");

    println!("cycle-tracker-end: deserialize data");

    println!("cycle-tracker-start: srs");
    verifier_index.srs = Arc::new(srs);
    println!("cycle-tracker-end: srs");

    println!("cycle-tracker-start: verify");
    let result = kimchi_verify(&proof, &verifier_index);
    println!("cycle-tracker-end: verify");

    sp1_zkvm::io::commit(&result);
}
