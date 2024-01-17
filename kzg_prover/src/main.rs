mod snarky_gate;

use std::{array, collections::HashMap, fs, ops::Neg, sync::Arc};

use ark_bn254::{Bn254, G1Affine, G2Affine};
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
        berkeley_columns::Column,
        constraints::ConstraintSystem,
        domains::EvaluationDomains,
        expr::{Linearization, PolishToken, RowOffset, Variable},
        gate::{CircuitGate, GateType},
        polynomials::{
            generic::testing::{create_circuit, fill_in_witness},
            range_check,
        },
        wires::{Wire, COLUMNS},
    },
    curve::KimchiCurve,
    groupmap::*,
    keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
    o1_utils::{foreign_field::BigUintForeignFieldHelpers, BigUintFieldHelpers, FieldHelpers},
    proof::ProverProof,
    prover,
    prover_index::{self, ProverIndex},
    verifier::{batch_verify, Context},
};
use num::{bigint::RandBigInt, BigUint};
use num_traits::{One, Zero};
use poly_commitment::{
    commitment::{combine_commitments, combine_evaluations, CommitmentCurve, Evaluation},
    evaluation_proof::{combine_polys, DensePolynomialOrEvaluations, OpeningProof},
    pairing_proof::{PairingProof, PairingSRS},
    srs::{endos, SRS},
    PolyComm, SRS as _,
};
use serde::{ser::SerializeStruct, Serialize};
use snarky_gate::SnarkyGate;

type PolynomialsToCombine<'a> = &'a [(
    DensePolynomialOrEvaluations<'a, ark_bn254::Fr, Radix2EvaluationDomain<ark_bn254::Fr>>,
    Option<usize>,
    PolyComm<ark_bn254::Fr>,
)];

type BaseField = ark_bn254::Fq;
type ScalarField = ark_bn254::Fr;
type G1 = GroupAffine<ark_bn254::g1::Parameters>;

type KeccakFqSponge = Keccak256FqSponge<BaseField, G1, ScalarField>;
type KeccakFrSponge = Keccak256FrSponge<ScalarField>;

type KZGProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;

fn main() {
    generate_verifier_circuit_proof();
    //generate_test_proof();
    generate_test_proof_for_evm_verifier();
}

fn generate_test_proof_for_evm_verifier() {
    let rng = &mut StdRng::from_seed([255u8; 32]);

    // Create range-check gadget
    let (mut next_row, mut gates) = CircuitGate::<ScalarField>::create_multi_range_check(0);

    // Create witness
    let witness = range_check::witness::create_multi::<ScalarField>(
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
    );

    // Temporary workaround for lookup-table/domain-size issue
    for _ in 0..(1 << 13) {
        gates.push(CircuitGate::zero(Wire::for_row(next_row)));
        next_row += 1;
    }

    // Create constraint system
    let cs = ConstraintSystem::<ScalarField>::create(gates)
        //.lookup(vec![range_check::gadget::lookup_table()])
        .build()
        .unwrap();

    let x = ark_bn254::Fr::rand(rng);
    let mut srs = create_srs(x, cs.gates.len(), cs.domain);
    srs.full_srs.add_lagrange_basis(cs.domain.d1);

    let (_endo_r, endo_q) = G1::endos();
    let index = ProverIndex::<G1, KZGProof>::create(cs, *endo_q, Arc::new(srs.clone()));

    let group_map = <G1 as CommitmentCurve>::Map::setup();
    let proof = ProverProof::create_recursive::<KeccakFqSponge, KeccakFrSponge>(
        &group_map,
        witness,
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();

    fs::write(
        "../eth_verifier/prover_proof.mpk",
        rmp_serde::to_vec_named(&proof).unwrap(),
    )
    .unwrap();
    fs::write(
        "../eth_verifier/verifier_index.mpk",
        rmp_serde::to_vec_named(&index.verifier_index()).unwrap(),
    )
    .unwrap();
    let srs_to_serialize = PairingSRS {
        full_srs: SRS {
            g: srs.full_srs.g[0..3].to_vec(),
            ..srs.full_srs
        },
        ..srs
    };
    fs::write(
        "../eth_verifier/urs.mpk",
        rmp_serde::to_vec_named(&srs_to_serialize).unwrap(),
    )
    .unwrap();
    fs::write(
        "../eth_verifier/linearization.mpk",
        &serialize_linearization(index.linearization),
    )
    .unwrap();
}

#[derive(Serialize)]
struct UnitVariant<'a> {
    variant: &'a str,
}

#[derive(Serialize)]
struct MdsInner {
    row: usize,
    col: usize,
}

#[derive(Serialize)]
struct Mds {
    mds: MdsInner,
}

struct Literal {
    literal: ScalarField,
}

impl Serialize for Literal {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut lit = serializer.serialize_struct("Literal", 1)?;
        let mut literal_ser = vec![];
        self.literal.serialize(&mut literal_ser).unwrap();
        lit.serialize_field("literal", &literal_ser)?;
        lit.end()
    }
}

#[derive(Serialize)]
struct Cell {
    variable: Variable<Column>,
}

#[derive(Serialize)]
struct Pow {
    pow: u64,
}

#[derive(Serialize)]
struct UnnormalizedLagrangeBasis {
    rowoffset: RowOffset,
}

#[derive(Serialize)]
struct Load {
    load: usize,
}

fn serialize_linearization(
    linearization: Linearization<Vec<PolishToken<ScalarField, Column>>, Column>,
) -> Vec<u8> {
    let constant_term_ser: Vec<_> = linearization
        .constant_term
        .iter()
        .map(|token| {
            match *token {
                PolishToken::Alpha => rmp_serde::to_vec_named(&UnitVariant { variant: "alpha" }),
                PolishToken::Beta => rmp_serde::to_vec_named(&UnitVariant { variant: "beta" }),
                PolishToken::Gamma => rmp_serde::to_vec_named(&UnitVariant { variant: "gamma" }),
                PolishToken::JointCombiner => rmp_serde::to_vec_named(&UnitVariant {
                    variant: "jointcombiner",
                }),
                PolishToken::EndoCoefficient => rmp_serde::to_vec_named(&UnitVariant {
                    variant: "endocoefficient",
                }),
                PolishToken::Mds { row, col } => rmp_serde::to_vec_named(&Mds {
                    mds: MdsInner { row, col },
                }),
                PolishToken::Literal(literal) => rmp_serde::to_vec_named(&Literal { literal }),
                PolishToken::Cell(variable) => rmp_serde::to_vec_named(&Cell { variable }),
                PolishToken::Dup => rmp_serde::to_vec_named(&UnitVariant { variant: "dup" }),
                PolishToken::Pow(pow) => rmp_serde::to_vec_named(&Pow { pow }),
                PolishToken::Add => rmp_serde::to_vec_named(&UnitVariant { variant: "add" }),
                PolishToken::Mul => rmp_serde::to_vec_named(&UnitVariant { variant: "mul" }),
                PolishToken::Sub => rmp_serde::to_vec_named(&UnitVariant { variant: "sub" }),
                PolishToken::VanishesOnZeroKnowledgeAndPreviousRows => {
                    rmp_serde::to_vec_named(&UnitVariant {
                        variant: "vanishesonzeroknowledgeandpreviousrows",
                    })
                }
                PolishToken::UnnormalizedLagrangeBasis(rowoffset) => {
                    rmp_serde::to_vec_named(&UnnormalizedLagrangeBasis { rowoffset })
                }
                PolishToken::Store => rmp_serde::to_vec_named(&UnitVariant { variant: "store" }),
                PolishToken::Load(load) => rmp_serde::to_vec_named(&Load { load }),
                _ => rmp_serde::to_vec_named(&UnitVariant { variant: "not implemented" }),
            }
            .unwrap()
        })
        .flatten()
        .collect();

    // Add bytes corresponding to an array type:

    let mut constant_term_ser = constant_term_ser.into_iter().rev().collect::<Vec<_>>();
    let len = linearization.constant_term.len();

    // we choose arr32, so length is made of the next 4 bytes:
    constant_term_ser.push((len & 0xFF) as u8);
    constant_term_ser.push(((len >> 8) & 0xFF) as u8);
    constant_term_ser.push(((len >> 16) & 0xFF) as u8);
    constant_term_ser.push(((len >> 24) & 0xFF) as u8);

    // and then the arr32 prefix
    constant_term_ser.push(0xdd);

    let constant_term_ser = constant_term_ser.into_iter().rev().collect::<Vec<_>>();

    constant_term_ser
}

fn generate_verifier_circuit_proof() {
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

    let pairing_proof = KZGProof::create(
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

    let endo_q = G1::endos().1;
    srs.full_srs.add_lagrange_basis(cs.domain.d1);
    let prover_index = ProverIndex::<G1, KZGProof>::create(cs, endo_q, Arc::new(srs.clone()));
    let verifier_index = prover_index.verifier_index();
    fs::write(
        "../eth_verifier/verifier_index.mpk",
        rmp_serde::to_vec(&verifier_index).unwrap(),
    )
    .unwrap();

    println!(
        "Is verifier circuit's KZG proof valid?: {:?}",
        pairing_proof.verify(&srs, &evaluations, polyscale, &evaluation_points)
    );
    println!("{}", verifier_index.powers_of_alpha);
}

fn generate_test_proof() {
    let public_input: Vec<ScalarField> = vec![42.into(); 5];
    let gates = create_circuit::<ScalarField>(0, public_input.len());

    // create witness
    let mut witness: [Vec<_>; COLUMNS] = array::from_fn(|_| vec![0.into(); gates.len()]);
    fill_in_witness::<ScalarField>(0, &mut witness, &[]);

    let cs = ConstraintSystem::<ScalarField>::create(gates)
        .build()
        .unwrap();

    const ZK_ROWS: usize = 3;
    let domain_size = cs.gates.len() + ZK_ROWS;
    let domain = EvaluationDomains::create(domain_size).unwrap();

    let n = domain.d1.size as usize;

    let srs = create_srs(42.into(), n, domain);
    let endo_q = G1::endos().1;
    let prover_index =
        ProverIndex::<G1, PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>>::create(
            cs,
            endo_q,
            Arc::new(srs.clone()),
        );

    let groupmap = <G1 as CommitmentCurve>::Map::setup();
    let prover_proof = ProverProof::create::<KeccakFqSponge, KeccakFrSponge>(
        &groupmap,
        witness,
        &[],
        &prover_index,
    )
    .unwrap();

    fs::write(
        "../eth_verifier/verifier_index.mpk",
        rmp_serde::to_vec(&prover_index.verifier_index()).unwrap(),
    )
    .unwrap();

    let context = Context {
        verifier_index: &prover_index.verifier_index(),
        proof: &prover_proof,
        public_input: &public_input,
    };

    let verified =
        batch_verify::<G1, KeccakFqSponge, KeccakFrSponge, KZGProof>(&groupmap, &[context]).is_ok();
    println!("Is test circuit's KZG proof valid?: {:?}", verified);
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
