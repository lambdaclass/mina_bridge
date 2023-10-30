//! Will create a KZG proof over a test circuit and serialize it into JSON
//! for feeding the Solidity verifier.
//!
//! This crate is based on `verifier_circuit_tests/` and the Kimchi test
//! "test_generic_gate_pairing".

use std::{array, fs};

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use ark_ff::UniformRand;
use kimchi::{
    circuits::{
        polynomials::generic::testing::{create_circuit, fill_in_witness},
        wires::COLUMNS,
    },
    groupmap::GroupMap,
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    poly_commitment::{
        commitment::CommitmentCurve,
        pairing_proof::{PairingProof, PairingSRS},
    },
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups_and_custom_srs,
};
use num_traits::Zero;

type Fp = ark_bn254::Fr;
type Proof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
type G = GroupAffine<ark_bn254::g1::Parameters>;

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<ark_bn254::g1::Parameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fp, SpongeParams>;

fn main() {
    // Create test circuit
    let gates = create_circuit(0, 0);

    // Create witnesses
    let mut witness: [Vec<Fp>; COLUMNS] = array::from_fn(|_| vec![Fp::zero(); gates.len()]);
    fill_in_witness(0, &mut witness, &vec![]);

    // Create proof
    let x = Fp::rand(&mut rand::rngs::OsRng);
    let prover_index = new_index_for_test_with_lookups_and_custom_srs::<_, Proof, _>(
        gates,
        0,
        0,
        vec![],
        None,
        true,
        None,
        |d1, size| {
            let mut srs = PairingSRS::create(x, size);
            srs.full_srs.add_lagrange_basis(d1);
            srs
        },
    );
    let group_map = <G as CommitmentCurve>::Map::setup();
    let proof = ProverProof::create::<BaseSponge, ScalarSponge>(
        &group_map,
        witness,
        &vec![],
        &prover_index,
    )
    .unwrap();

    let verifier_index = prover_index.verifier_index();

    // Serialize into JSON file
    fs::write("proof.json", serde_json::to_string_pretty(&proof).unwrap()).unwrap();
    fs::write(
        "verifier_index.json",
        serde_json::to_string_pretty(&verifier_index).unwrap(),
    )
    .unwrap();

    // Serialize OpeningProof into JSON and MessagePack
    fs::write(
        "opening_proof.json",
        serde_json::to_string_pretty(&proof.proof).unwrap(),
    )
    .unwrap();
    fs::write(
        "opening_proof.mpk",
        rmp_serde::to_vec(&proof.proof).unwrap(),
    )
    .unwrap();

    let srs = (**verifier_index.srs()).clone();

    // Serialize URS into JSON and MessagePack
    fs::write("urs.json", serde_json::to_vec(&srs.full_srs).unwrap()).unwrap();
    fs::write("urs.mpk", rmp_serde::to_vec(&srs.full_srs).unwrap()).unwrap();
}
