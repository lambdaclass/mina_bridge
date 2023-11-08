use ark_ec::short_weierstrass_jacobian::GroupAffine;
use ark_poly::{
    univariate::DenseOrSparsePolynomial, univariate::DensePolynomial, Evaluations, Polynomial,
    Radix2EvaluationDomain, UVPolynomial,
};
use ark_std::{rand, UniformRand};
use kimchi::circuits::{
    constraints::{selector_polynomial, ConstraintSystem},
    domains::EvaluationDomains,
    gate::{CircuitGate, GateType},
    polynomials::generic::testing::create_circuit,
};
use num_traits::{One, Zero};
use poly_commitment::{
    evaluation_proof::{combine_polys, DensePolynomialOrEvaluations},
    pairing_proof::PairingSRS,
    PolyComm, SRS,
};

type PolynomialsToCombine<'a> = &'a [(
    DensePolynomialOrEvaluations<'a, ark_bn254::Fr, Radix2EvaluationDomain<ark_bn254::Fr>>,
    Option<usize>,
    PolyComm<ark_bn254::Fr>,
)];

fn main() {
    let rng = &mut rand::rngs::OsRng;

    let gates: Vec<CircuitGate<ark_bn254::Fr>> = create_circuit(0, 0);
    const ZK_ROWS: usize = 3;
    let domain_size = gates.len() + ZK_ROWS;
    let domain = EvaluationDomains::create(domain_size).unwrap();

    let disable_gates_checks = false;

    let foreign_field_add_selector8 = selector_polynomial(
        GateType::ForeignFieldAdd,
        &gates,
        &domain,
        &domain.d8,
        disable_gates_checks,
    );

    let cs = ConstraintSystem::<ark_bn254::Fr>::create(gates)
        .build()
        .unwrap();

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

    let generic_selector4 = generic_selector.evaluate_over_domain_by_ref(cs.domain.d4);

    let x = ark_bn254::Fr::rand(rng);
    let srs = PairingSRS::create(x, cs.domain.d1.size as usize);

    let evaluations_form = |e| DensePolynomialOrEvaluations::Evaluations(e, cs.domain.d1);

    let non_hiding = |d1_size: usize| PolyComm {
        unshifted: vec![ark_bn254::Fr::zero(); d1_size],
        shifted: None,
    };

    let fixed_hiding = |d1_size: usize| PolyComm {
        unshifted: vec![ark_bn254::Fr::one(); d1_size],
        shifted: None,
    };

    const NUM_CHUNKS: usize = 1;

    let polynomials = vec![
        (
            evaluations_form(&foreign_field_add_selector8),
            None,
            non_hiding(NUM_CHUNKS),
        ),
        (
            evaluations_form(&generic_selector4),
            None,
            fixed_hiding(NUM_CHUNKS),
        ),
    ];

    // Dummy values
    let zeta = ark_bn254::Fr::rand(rng);
    let omega = cs.domain.d1.group_gen;
    let zeta_omega = zeta * omega;
    let v = ark_bn254::Fr::rand(rng);

    let quotient = create_proof_quotient(&srs, &polynomials, &[zeta, zeta_omega], v).unwrap();
    println!("{:?}", quotient);
}

fn create_proof_quotient(
    srs: &PairingSRS<ark_ec::bn::Bn<ark_bn254::Parameters>>,
    plnms: PolynomialsToCombine, // vector of polynomial with optional degree bound and commitment randomness
    elm: &[ark_bn254::Fr],       // vector of evaluation points
    polyscale: ark_bn254::Fr,    // scaling factor for polynoms
) -> Option<GroupAffine<ark_bn254::g1::Parameters>> {
    let (p, _) = combine_polys::<
        GroupAffine<ark_bn254::g1::Parameters>,
        Radix2EvaluationDomain<ark_bn254::Fr>,
    >(plnms, polyscale, srs.full_srs.g.len());
    let evals: Vec<_> = elm.iter().map(|pt| p.evaluate(pt)).collect();

    let quotient_poly = {
        let eval_polynomial = eval_polynomial(elm, &evals);
        let divisor_polynomial = divisor_polynomial(elm);
        let numerator_polynomial = &p - &eval_polynomial;
        let (quotient, remainder) = DenseOrSparsePolynomial::divide_with_q_and_r(
            &numerator_polynomial.into(),
            &divisor_polynomial.into(),
        )?;
        if !remainder.is_zero() {
            return None;
        }
        quotient
    };

    Some(
        srs.full_srs
            .commit_non_hiding(&quotient_poly, 1, None)
            .unshifted[0],
    )
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
