use std::array;

use ark_ff::fields::FpParameters;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::fields::{FpParameters as FrParameters, FqParameters};
use kimchi::{
    circuits::{
        gate::CircuitGate,
        polynomials::generic::testing::{create_circuit, fill_in_witness},
        wires::COLUMNS,
    },
    mina_curves::pasta::{Fp, Vesta, VestaParameters},
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    poly_commitment::commitment::CommitmentCurve,
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups,
    verifier::verify,
};
use num_traits::identities::Zero;

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<VestaParameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fp, SpongeParams>;

fn main() {
    let gates = create_circuit(0, 0);

    // create witness
    let mut witness: [Vec<Fp>; COLUMNS] = array::from_fn(|_| vec![Fp::zero(); gates.len()]);
    fill_in_witness(0, &mut witness, &[]);
    println!("VESTA ORDER: {}", <FqParameters as FpParameters>::MODULUS);
    println!("PALLAS ORDER: {}", FrParameters::MODULUS);

    // create and verify proof based on the witness
    prove_and_verify(gates, witness);
}

fn prove_and_verify(gates: Vec<CircuitGate<Fp>>, witness: [Vec<Fp>; COLUMNS]) {
    let index = new_index_for_test_with_lookups::<Vesta>(gates, 0, 0, vec![], Some(vec![]), false);

    let verifier_index = index.verifier_index();
    let prover = index;
    let public_inputs = vec![];

    prover.verify(&witness, &public_inputs).unwrap();

    // add the proof to the batch
    let group_map = <Vesta as CommitmentCurve>::Map::setup();

    let proof = ProverProof::create_recursive::<BaseSponge, ScalarSponge>(
        &group_map,
        witness,
        &[],
        &prover,
        vec![],
        None,
    )
    .map_err(|e| e.to_string())
    .unwrap();

    // verify the proof (propagate any errors)
    verify::<Vesta, BaseSponge, ScalarSponge>(&group_map, &verifier_index, &proof, &public_inputs)
        .unwrap();
}
