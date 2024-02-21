use std::{array, collections::HashMap, fs};

use ark_ff::Fp256;
use kimchi::{
    circuits::{
        polynomials::generic::testing::{create_circuit, fill_in_witness},
        wires::COLUMNS,
    },
    curve::KimchiCurve,
    groupmap::GroupMap,
    mina_curves::pasta::{fields::FqParameters, Pallas},
    o1_utils::FieldHelpers,
    poly_commitment::commitment::CommitmentCurve,
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups,
};
use verifier_circuit_tests::{
    to_batch_step1, to_batch_step2, BaseSponge, ProverProofTS, ScalarSponge, UncompressedPolyComm,
    VerifierIndexTS,
};

fn main() {
    // Create test circuit
    let gates = create_circuit(0, 0);
    let num_gates = gates.len();

    // Index
    let prover_index =
        new_index_for_test_with_lookups::<Pallas>(gates, 0, 0, vec![], Some(vec![]), false, None);

    // Print values for hardcoding in verifier_circuit/
    let verifier_index = prover_index.verifier_index();
    let mds = Pallas::sponge_params()
        .mds
        .iter()
        .map(|arr| arr.iter().map(|e| e.to_hex()).collect::<Vec<_>>())
        .collect::<Vec<_>>();
    println!("Powers of alpha: {:?}", verifier_index.powers_of_alpha);
    println!("Sponge MDS: {:?}", mds);

    // Export for typescript tests
    fs::write(
        "../verifier_circuit/test_data/verifier_index.json",
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
        "../verifier_circuit/test_data/proof.json",
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
        "../verifier_circuit/test_data/lagrange_bases.json",
        serde_json::to_string_pretty(&uncompressed_lagrange_bases).unwrap(),
    )
    .unwrap();

    let public_inputs = vec![];

    to_batch_step1(&proof, &verifier_index).unwrap();
    to_batch_step2(&verifier_index, &public_inputs).unwrap();
}

#[cfg(test)]
mod unit_tests {
    use kimchi::{
        mina_poseidon::sponge::ScalarChallenge,
        poly_commitment::commitment::{b_poly, b_poly_coefficients},
    };
    use num_bigint::BigUint;
    use verifier_circuit_tests::PallasScalar;

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
        println!("to_field_with_length: {}", result);
    }

    #[test]
    fn b_poly_test() {
        // arbitrary values
        let coeffs = vec![
            PallasScalar::from(42),
            PallasScalar::from(25),
            PallasScalar::from(420),
        ];
        let x = PallasScalar::from(12);

        let result = b_poly(&coeffs, x);
        println!("b_poly_test: {}", result);
    }

    #[test]
    fn b_poly_coefficients_test() {
        // arbitrary values
        let coeffs = vec![PallasScalar::from(42), PallasScalar::from(25)];

        let result: Vec<_> = b_poly_coefficients(&coeffs)
            .iter()
            .map(|e| e.to_string())
            .collect();
        println!("b_poly_coefficients_test: {:?}", result);
    }
}
