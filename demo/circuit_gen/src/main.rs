//! Will create a KZG proof over a test circuit and serialize it into JSON
//! for feeding the Solidity verifier.
//!
//! This crate is based on `verifier_circuit_tests/` and the Kimchi test
//! "test_generic_gate_pairing".

use std::{array, fs};

use ark_bn254::Fr as ScalarField;
use ark_bn254::{G1Affine as G1, G2Affine as G2, Parameters};
use ark_ec::bn::{Bn, G2Affine};
use ark_ec::msm::VariableBaseMSM;
use ark_ec::{short_weierstrass_jacobian::GroupAffine, AffineCurve};
use ark_ff::{PrimeField, UniformRand};
use ark_poly::{univariate::DensePolynomial, Radix2EvaluationDomain as D, UVPolynomial};
use ark_poly::{EvaluationDomain, Polynomial};
use kimchi::poly_commitment::commitment::combine_commitments;
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
        commitment::{combine_evaluations, CommitmentCurve, Evaluation},
        evaluation_proof::DensePolynomialOrEvaluations,
        pairing_proof::{PairingProof, PairingSRS},
        srs::SRS,
        SRS as _,
    },
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups_and_custom_srs,
};
use num_traits::Zero;
use rand::rngs::StdRng;
use rand_core::SeedableRng;

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

    // Serialize public evals into JSON and MessagePack
    fs::write(
        "public_evals.json",
        serde_json::to_vec(&proof.evals.public).unwrap(),
    )
    .unwrap();
    fs::write(
        "public_evals.mpk",
        rmp_serde::to_vec(&proof.evals.public).unwrap(),
    )
    .unwrap();

    pairing_proof_test();
}

fn pairing_proof_test() {
    let n = 64;
    let domain = D::<ScalarField>::new(n).unwrap();

    let rng = &mut StdRng::from_seed([0u8; 32]);

    let x = ScalarField::rand(rng);

    let mut srs = SRS::<G1>::create_trusted_setup(x, n);
    let verifier_srs = SRS::<G2>::create_trusted_setup(x, 3);
    srs.add_lagrange_basis(domain);

    let srs = PairingSRS {
        full_srs: srs,
        verifier_srs,
    };

    let polynomials: Vec<_> = (0..4)
        .map(|_| {
            let coeffs = (0..63).map(|_| ScalarField::rand(rng)).collect();
            DensePolynomial::from_coefficients_vec(coeffs)
        })
        .collect();

    let comms: Vec<_> = polynomials
        .iter()
        .map(|p| srs.full_srs.commit(p, 1, None, rng))
        .collect();

    let polynomials_and_blinders: Vec<(DensePolynomialOrEvaluations<_, D<_>>, _, _)> = polynomials
        .iter()
        .zip(comms.iter())
        .map(|(p, comm)| {
            let p = DensePolynomialOrEvaluations::DensePolynomial(p);
            (p, None, comm.blinders.clone())
        })
        .collect();

    let evaluation_points = vec![ScalarField::rand(rng), ScalarField::rand(rng)];

    let evaluations: Vec<_> = polynomials
        .iter()
        .zip(comms)
        .map(|(p, commitment)| {
            let evaluations = evaluation_points
                .iter()
                .map(|x| {
                    // Inputs are chosen to use only 1 chunk
                    vec![p.evaluate(x)]
                })
                .collect();
            Evaluation {
                commitment: commitment.commitment,
                evaluations,
                degree_bound: None,
            }
        })
        .collect();

    let polyscale = ScalarField::rand(rng);

    let pairing_proof = PairingProof::<Bn<Parameters>>::create(
        &srs,
        polynomials_and_blinders.as_slice(),
        &evaluation_points,
        polyscale,
    )
    .unwrap();

    let poly_commitment = {
        let mut scalars: Vec<_> = Vec::new();
        let mut points = Vec::new();
        combine_commitments(
            &evaluations,
            &mut scalars,
            &mut points,
            polyscale,
            ScalarField::from(1)
        );
        let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();

        VariableBaseMSM::multi_scalar_mul(&points, &scalars)
    };
    let evals = combine_evaluations(&evaluations, polyscale);
    let blinding_commitment = srs.full_srs.h.mul(pairing_proof.blinding);
    let eval_commitment = srs
        .full_srs
        .commit_non_hiding(&eval_polynomial(&evaluation_points, &evals), 1, None)
        .unshifted[0]
        .into_projective();

    let divisor_commitment = srs
        .verifier_srs
        .commit_non_hiding(&divisor_polynomial(&evaluation_points), 1, None)
        .unshifted[0];
    let numerator_commitment = { poly_commitment - eval_commitment - blinding_commitment };
    let generator = G2::prime_subgroup_generator();

    println!("{}", numerator_commitment);
    println!("");
    println!("{}", generator);
    println!("");
    println!("{}", pairing_proof.quotient);
    println!("");
    println!("{}", divisor_commitment);

    let res = pairing_proof.verify(&srs, &evaluations, polyscale, &evaluation_points);

    assert!(res);
}

fn divisor_polynomial<F: PrimeField>(elm: &[F]) -> DensePolynomial<F> {
    elm.iter()
        .map(|value| DensePolynomial::from_coefficients_slice(&[-(*value), F::one()]))
        .reduce(|poly1, poly2| &poly1 * &poly2)
        .unwrap()
}

/// The polynomial that evaluates to each of `evals` for the respective `elm`s.
fn eval_polynomial<F: PrimeField>(elm: &[F], evals: &[F]) -> DensePolynomial<F> {
    assert_eq!(elm.len(), evals.len());
    let (zeta, zeta_omega) = if elm.len() == 2 {
        (elm[0], elm[1])
    } else {
        todo!()
    };
    let (eval_zeta, eval_zeta_omega) = if evals.len() == 2 {
        (evals[0], evals[1])
    } else {
        todo!()
    };

    // The polynomial that evaluates to `p(zeta)` at `zeta` and `p(zeta_omega)` at
    // `zeta_omega`.
    // We write `p(x) = a + bx`, which gives
    // ```text
    // p(zeta) = a + b * zeta
    // p(zeta_omega) = a + b * zeta_omega
    // ```
    // and so
    // ```text
    // b = (p(zeta_omega) - p(zeta)) / (zeta_omega - zeta)
    // a = p(zeta) - b * zeta
    // ```
    let b = (eval_zeta_omega - eval_zeta) / (zeta_omega - zeta);
    let a = eval_zeta - b * zeta;
    DensePolynomial::from_coefficients_slice(&[a, b])
}
