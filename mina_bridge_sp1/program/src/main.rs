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
type KimchiSRS = SRS<Curve>;
type KimchiLagrangeBases = HashMap<usize, Vec<PolyComm<Curve>>>;

pub fn main() {
    println!("cycle-tracker-start: deserialize data");

    println!("Proof size: {}", std::mem::size_of::<KimchiProof>());
    println!(
        "Verifier index size: {}",
        std::mem::size_of::<KimchiVerifierIndex>()
    );
    println!("SRS size: {}", std::mem::size_of::<KimchiSRS>());
    println!(
        "Lag. bases size: {}",
        std::mem::size_of::<KimchiLagrangeBases>()
    );

    println!("cycle-tracker-start: deserialize proof");
    let proof = sp1_zkvm::io::read::<KimchiProof>();
    println!("cycle-tracker-end: deserialize proof");

    println!("cycle-tracker-start: deserialize verifier index");
    let mut verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    println!("cycle-tracker-end: deserialize verifier index");

    println!("cycle-tracker-start: deserialize srs");
    let srs = unsafe { std::ptr::read(sp1_zkvm::io::read_vec().as_ptr() as *const _) };
    println!("cycle-tracker-end: deserialize srs");

    println!("cycle-tracker-end: deserialize data");

    println!("cycle-tracker-start: srs");
    verifier_index.srs = Arc::new(srs);
    println!("cycle-tracker-end: srs");

    println!("cycle-tracker-start: verify");
    let result = kimchi_verify(&proof, &verifier_index);
    println!("cycle-tracker-end: verify");

    sp1_zkvm::io::commit(&result);
}
