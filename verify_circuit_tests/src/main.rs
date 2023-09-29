use std::{array, collections::HashMap, fs};

use ark_ff::Fp256;
use kimchi::{
    circuits::{
        polynomials::generic::testing::{create_circuit, fill_in_witness},
        wires::COLUMNS,
    },
    groupmap::GroupMap,
    mina_curves::pasta::{fields::FqParameters, Pallas},
    poly_commitment::commitment::CommitmentCurve,
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups,
};
use verify_circuit_tests::{
    to_batch_step1, to_batch_step2, BaseSponge, ProverProofTS, ScalarSponge, UncompressedPolyComm,
    VerifierIndexTS,
};

fn main() {
    // Create test circuit
    let gates = create_circuit(0, 0);
    let num_gates = gates.len();

    // Index
    let prover_index =
        new_index_for_test_with_lookups::<Pallas>(gates, 0, 0, vec![], Some(vec![]), false);
    let verifier_index = prover_index.verifier_index();
    // Export for typescript tests
    fs::write(
        "../evm_bridge/test/verifier_index.json",
        serde_json::to_string_pretty(&VerifierIndexTS::from(&verifier_index)).unwrap(),
    )
    .unwrap();

    // Create proof
    let proof = {
        let groupmap = <Pallas as CommitmentCurve>::Map::setup();
        // dummy array that will get filled
        let mut witness: [Vec<Fp256<FqParameters>>; COLUMNS] =
            array::from_fn(|_| vec![1u32.into(); num_gates]);
        fill_in_witness(0, &mut witness, &[]);

        ProverProof::create::<BaseSponge, ScalarSponge>(&groupmap, witness, &[], &prover_index)
            .unwrap()
    };

    // Export proof
    fs::write(
        "../evm_bridge/test/proof.json",
        serde_json::to_string_pretty(&ProverProofTS::from(&proof)).unwrap(),
    )
    .unwrap();

    // Export lagrange_bases (needed for Typescript SRS)
    let lagrange_bases = &verifier_index.srs().lagrange_bases.clone();
    let uncompressed_lagrange_bases: HashMap<_, _> = lagrange_bases
        .iter()
        .map(|(u, comm_vec)| {
            (
                u,
                comm_vec
                    .iter()
                    .map(UncompressedPolyComm::from)
                    .collect::<Vec<_>>(),
            )
        })
        .collect();
    fs::write(
        "../evm_bridge/test/lagrange_bases.json",
        serde_json::to_string_pretty(&uncompressed_lagrange_bases).unwrap(),
    )
    .unwrap();

    let public_inputs = vec![];

    to_batch_step1(&proof).unwrap();
    to_batch_step2(&verifier_index, &public_inputs).unwrap();
}

#[cfg(test)]
mod unit_tests {
    use kimchi::mina_poseidon::sponge::ScalarChallenge;
    use num_bigint::BigUint;
    use verify_circuit_tests::PallasScalar;

    #[test]
    fn to_field_with_length() {
        let chal = ScalarChallenge(BigUint::parse_bytes(b"123456789", 16).unwrap().into());
        let endo_coeff: PallasScalar = BigUint::parse_bytes(
            b"397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1",
            16,
        )
        .unwrap()
        .into();
        let length_in_bits = 10;

        let result = chal.to_field_with_length(length_in_bits, &endo_coeff);
        println!("{}", result);
    }
}
