mod snarky_gate;

use std::{fs, ops::Neg, sync::Arc};

use ark_bn254::{G1Affine, G2Affine};
use ark_ec::{
    msm::VariableBaseMSM, short_weierstrass_jacobian::GroupAffine, AffineCurve, ProjectiveCurve,
};
use ark_ff::PrimeField;
use ark_poly::{
    univariate::DensePolynomial, Evaluations, Polynomial, Radix2EvaluationDomain, UVPolynomial,
};
use ark_serialize::{CanonicalSerialize, SerializationError};
use ark_std::{
    rand::{rngs::StdRng, SeedableRng},
    UniformRand,
};
use kimchi::{
    circuits::{
        constraints::ConstraintSystem,
        domains::EvaluationDomains,
        gate::{CircuitGate, GateType},
    },
    curve::KimchiCurve,
    prover_index::ProverIndex,
};
use num_traits::{One, Zero};
use poly_commitment::{
    commitment::{combine_commitments, combine_evaluations, Evaluation},
    evaluation_proof::{DensePolynomialOrEvaluations, OpeningProof},
    pairing_proof::{PairingProof, PairingSRS},
    srs::SRS,
    SRS as _,
};
use snarky_gate::SnarkyGate;

fn main() {
    let rng = &mut StdRng::from_seed([0u8; 32]);

    let gates = read_gates_file();

    let cs = ConstraintSystem::<ark_bn254::Fr>::create(gates)
        .build()
        .unwrap();

    const ZK_ROWS: usize = 3;
    let domain_size = cs.gates.len() + ZK_ROWS;
    let domain = EvaluationDomains::create(domain_size).unwrap();

    let n = domain.d1.size as usize;
    let x = ark_bn254::Fr::rand(rng);

    let mut srs = create_srs(x, n, domain);

    let polynomials = create_selector_dense_polynomials(cs.clone(), domain);

    let comms: Vec<_> = polynomials
        .iter()
        .map(|p| srs.full_srs.commit(p, 1, None, rng))
        .collect();

    let polynomials_and_blinders: Vec<(
        DensePolynomialOrEvaluations<_, Radix2EvaluationDomain<_>>,
        _,
        _,
    )> = polynomials
        .iter()
        .zip(comms.iter())
        .map(|(p, comm)| {
            let p = DensePolynomialOrEvaluations::DensePolynomial(p);
            (p, None, comm.blinders.clone())
        })
        .collect();

    let evaluation_points = vec![ark_bn254::Fr::rand(rng), ark_bn254::Fr::rand(rng)];

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

    let polyscale = ark_bn254::Fr::rand(rng);

    let pairing_proof = PairingProof::<ark_ec::bn::Bn<ark_bn254::Parameters>>::create(
        &srs,
        polynomials_and_blinders.as_slice(),
        &evaluation_points,
        polyscale,
    )
    .unwrap();

    let poly_commitment = create_poly_commitment(&evaluations, polyscale);
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
    let numerator_commitment =
        (poly_commitment - eval_commitment - blinding_commitment).into_affine();

    let numerator_serialized = serialize_g1point_for_verifier(numerator_commitment).unwrap();
    let quotient_serialized = serialize_g1point_for_verifier(pairing_proof.quotient.neg()).unwrap();
    let divisor_serialized = serialize_g2point_for_verifier(divisor_commitment).unwrap();

    let mut points_serialized = numerator_serialized.clone();
    points_serialized.extend(quotient_serialized);
    points_serialized.extend(divisor_serialized);

    fs::write("../eth_verifier/proof.mpk", points_serialized).unwrap();

    type G1 = GroupAffine<ark_bn254::g1::Parameters>;
    let endo_q = G1::endos().1;
    srs.full_srs.add_lagrange_basis(cs.domain.d1);
    let prover_index =
        ProverIndex::<G1, OpeningProof<G1>>::create(cs, endo_q, Arc::new(srs.clone().full_srs));
    let verifier_index = prover_index.verifier_index();
    fs::write(
        "../eth_verifier/verifier_index.mpk",
        rmp_serde::to_vec(&verifier_index).unwrap(),
    )
    .unwrap();

    println!(
        "Is KZG proof valid?: {:?}",
        pairing_proof.verify(&srs, &evaluations, polyscale, &evaluation_points)
    );
    println!("{}", verifier_index.powers_of_alpha);
}

fn serialize_g1point_for_verifier(point: G1Affine) -> Result<Vec<u8>, SerializationError> {
    let mut point_serialized = vec![];
    point.serialize_uncompressed(&mut point_serialized)?;
    point_serialized[..32].reverse();
    point_serialized[32..].reverse();
    Ok(point_serialized)
}

fn serialize_g2point_for_verifier(point: G2Affine) -> Result<Vec<u8>, SerializationError> {
    let mut point_serialized = vec![];
    point.serialize_uncompressed(&mut point_serialized)?;
    point_serialized[..64].reverse();
    point_serialized[64..].reverse();
    Ok(point_serialized)
}

fn read_gates_file() -> Vec<CircuitGate<ark_ff::Fp256<ark_bn254::FrParameters>>> {
    let gates_json = fs::read_to_string("gates.json").unwrap();
    let snarky_gates: Vec<SnarkyGate> = serde_json::from_str(&gates_json).unwrap();

    snarky_gates
        .iter()
        .map(|gate| gate.clone().into())
        .collect()
}

fn create_poly_commitment(
    evaluations: &Vec<Evaluation<GroupAffine<ark_bn254::g1::Parameters>>>,
    polyscale: ark_ff::Fp256<ark_bn254::FrParameters>,
) -> ark_ec::short_weierstrass_jacobian::GroupProjective<ark_bn254::g1::Parameters> {
    let poly_commitment = {
        let mut scalars: Vec<ark_bn254::Fr> = Vec::new();
        let mut points = Vec::new();
        combine_commitments(
            evaluations,
            &mut scalars,
            &mut points,
            polyscale,
            ark_bn254::Fr::from(1),
        );
        let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();

        VariableBaseMSM::multi_scalar_mul(&points, &scalars)
    };
    poly_commitment
}

fn create_selector_dense_polynomials(
    cs: ConstraintSystem<ark_ff::Fp256<ark_bn254::FrParameters>>,
    domain: EvaluationDomains<ark_ff::Fp256<ark_bn254::FrParameters>>,
) -> Vec<DensePolynomial<ark_ff::Fp256<ark_bn254::FrParameters>>> {
    let foreign_field_add_selector =
        selector_polynomial(GateType::ForeignFieldAdd, &cs.gates, &domain);

    let generic_selector =
        Evaluations::<ark_bn254::Fr, Radix2EvaluationDomain<ark_bn254::Fr>>::from_vec_and_domain(
            cs.gates
                .iter()
                .map(|gate| {
                    if matches!(gate.typ, GateType::Generic) {
                        ark_bn254::Fr::one()
                    } else {
                        ark_bn254::Fr::zero()
                    }
                })
                .collect(),
            cs.domain.d1,
        )
        .interpolate();

    let polynomials: Vec<_> = vec![foreign_field_add_selector, generic_selector];
    polynomials
}

fn create_srs(
    x: ark_ff::Fp256<ark_bn254::FrParameters>,
    n: usize,
    domain: EvaluationDomains<ark_ff::Fp256<ark_bn254::FrParameters>>,
) -> PairingSRS<ark_ec::bn::Bn<ark_bn254::Parameters>> {
    let mut srs = SRS::<ark_bn254::G1Affine>::create_trusted_setup(x, n);
    let verifier_srs = SRS::<ark_bn254::G2Affine>::create_trusted_setup(x, 3);
    srs.add_lagrange_basis(domain.d1);

    PairingSRS {
        full_srs: srs,
        verifier_srs,
    }
}

/// The polynomial that evaluates to each of `evals` for the respective `elm`s.
fn eval_polynomial(
    elm: &[ark_bn254::Fr],
    evals: &[ark_bn254::Fr],
) -> DensePolynomial<ark_bn254::Fr> {
    let zeta = elm[0];
    let zeta_omega = elm[1];
    let eval_zeta = evals[0];
    let eval_zeta_omega = evals[1];

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

/// The polynomial that evaluates to `0` at the evaluation points.
fn divisor_polynomial(elm: &[ark_bn254::Fr]) -> DensePolynomial<ark_bn254::Fr> {
    elm.iter()
        .map(|value| DensePolynomial::from_coefficients_slice(&[-(*value), ark_bn254::Fr::one()]))
        .reduce(|poly1, poly2| &poly1 * &poly2)
        .unwrap()
}

/// Create selector polynomial for a circuit gate
fn selector_polynomial(
    gate_type: GateType,
    gates: &[CircuitGate<ark_bn254::Fr>],
    domain: &EvaluationDomains<ark_bn254::Fr>,
) -> DensePolynomial<ark_bn254::Fr> {
    // Coefficient form
    Evaluations::<_, Radix2EvaluationDomain<_>>::from_vec_and_domain(
        gates
            .iter()
            .map(|gate| {
                if gate.typ == gate_type {
                    ark_bn254::Fr::one()
                } else {
                    ark_bn254::Fr::zero()
                }
            })
            .collect(),
        domain.d1,
    )
    .interpolate()
}
