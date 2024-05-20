//! A simple program to be proven inside the zkVM.

#![no_main]

use std::sync::Arc;

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
type KimchiSRS = SRS<Curve>;

unsafe fn as_bytes<T: Sized>(data: &T) -> &[u8] {
    std::slice::from_raw_parts((data as *const T) as *const u8, std::mem::size_of_val(data))
}

pub fn main() {
    println!("cycle-tracker-start: deserialize data");

    println!("cycle-tracker-start: deserialize proof");
    let proof = sp1_zkvm::io::read::<KimchiProof>();
    println!("cycle-tracker-end: deserialize proof");

    println!("cycle-tracker-start: deserialize verifier index");
    let mut verifier_index = sp1_zkvm::io::read::<KimchiVerifierIndex>();
    println!("cycle-tracker-end: deserialize verifier index");

    println!("cycle-tracker-start: read srs bytes");
    let srs_bytes = sp1_zkvm::io::read_vec();
    println!("cycle-tracker-end: read srs bytes");

    println!("cycle-tracker-start: deserialize srs");
    sp1_zkvm::precompiles::unconstrained! {
        let srs = bincode::deserialize::<KimchiSRS>(&srs_bytes).expect("can't deserialize srs");
        unsafe {sp1_zkvm::io::hint_slice(as_bytes(&srs))};
    };
    println!("cycle-tracker-end: deserialize srs");

    println!("cycle-tracker-end: deserialize data");

    println!("cycle-tracker-start: srs");
    unsafe {
        let srs = sp1_zkvm::io::read_vec().as_ptr() as *const KimchiSRS;
        verifier_index.srs = Arc::new(srs.read_unaligned());
    };
    println!("cycle-tracker-end: srs");

    println!("cycle-tracker-start: verify");
    let result = kimchi_verify(&proof, &verifier_index);
    println!("cycle-tracker-end: verify");

    sp1_zkvm::io::commit(&result);
}
