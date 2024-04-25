mod snarky_gate;

use std::{array, collections::HashMap, fs, ops::Neg, sync::Arc};

use ark_bn254::{G1Affine, G2Affine, Parameters};
use ark_ec::{
    bn::Bn, msm::VariableBaseMSM, short_weierstrass_jacobian::GroupAffine, AffineCurve,
    ProjectiveCurve,
};
use ark_ff::{BigInteger256, Field, PrimeField};
use ark_poly::{
    univariate::DensePolynomial, EvaluationDomain, Evaluations, Polynomial, Radix2EvaluationDomain,
    UVPolynomial,
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
        expr::{Column, Constants, ExprError, Linearization, PolishToken, Variable},
        gate::{CircuitGate, CurrOrNext, GateType},
        lookup::lookups::LookupPattern,
        polynomials::{
            generic::testing::{create_circuit, fill_in_witness},
            permutation::eval_vanishes_on_last_n_rows,
            range_check,
        },
        wires::{Wire, COLUMNS},
    },
    curve::KimchiCurve,
    groupmap::*,
    keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
    o1_utils::{foreign_field::BigUintForeignFieldHelpers, BigUintFieldHelpers},
    proof::{PointEvaluations, ProofEvaluations, ProverProof},
    prover_index::ProverIndex,
    verifier::{batch_verify, to_batch, Context},
};
use mina_poseidon::dummy_values::kimchi_dummy;
use num::{bigint::RandBigInt, BigUint};
use num_traits::{One, Zero};
use o1_utils::FieldHelpers;
use poly_commitment::{
    commitment::{
        combine_commitments, combine_evaluations, BatchEvaluationProof, CommitmentCurve, Evaluation,
    },
    evaluation_proof::DensePolynomialOrEvaluations,
    pairing_proof::{PairingProof, PairingSRS},
    srs::SRS,
    PolyComm, SRS as _,
};
use serde::{ser::SerializeStruct, Serialize};
use serializer::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254PolishToken, BN254ProofEvaluations},
};
use snarky_gate::SnarkyGate;

type BaseField = ark_bn254::Fq;
type ScalarField = ark_bn254::Fr;
type G1 = GroupAffine<ark_bn254::g1::Parameters>;

type KeccakFqSponge = Keccak256FqSponge<BaseField, G1, ScalarField>;
type KeccakFrSponge = Keccak256FrSponge<ScalarField>;

type KZGProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;

fn main() {
    // generate_test_proof_for_demo();
    //generate_test_proof();
    generate_proof();
    // generate_test_proof_for_evm_verifier();
}

fn generate_proof() {
    let (proof, public_input): (ProverProof<G1, KZGProof>, Vec<[u64; 4]>) =
        serde_json::from_str(&fs::read_to_string("./proof_with_public.json").unwrap()).unwrap();

    let index: ProverIndex<G1, KZGProof> =
        serde_json::from_str(&fs::read_to_string("./index.json").unwrap()).unwrap();
    println!("domain size: {}", index.cs.domain.d1.size);

    let (_endo_q, endo_r) = G1::endos();
    println!("cs endo: {}", endo_r); // ProverIndex::create() sets cs endo to endo_r

    // FIXME: this is hacky, this should be optimized to avoid cloning
    // This seed (42) is also used for generating a trusted setup in Solidity.
    let x = ark_bn254::Fr::from(42);
    let mut srs = PairingSRS::create(x, index.cs.domain.d1.size as usize); // size is 8192
    srs.full_srs.add_lagrange_basis(index.cs.domain.d1);

    let index: ProverIndex<G1, KZGProof> =
        ProverIndex::create(index.cs.clone(), index.cs.endo, Arc::new(srs));
    println!(
        "lagrange basis len: {:?}",
        index
            .srs
            .full_srs
            .get_lagrange_basis(index.cs.domain.d1.size())
            .unwrap()
            .len()
    );
    let verifier_index = index.verifier_index();
    let domain_size = index.cs.domain.d1.size();

    println!(
        "verifier_index digest: {}",
        verifier_index.digest::<KeccakFqSponge>()
    );

    // The verifier circuit has only one public input
    let public_input_vec: Vec<_> = public_input
        .iter()
        .map(|&p_i| ark_bn254::Fr::new(BigInteger256::new(p_i)))
        .collect();
    let public_input = public_input_vec.first().unwrap();
    println!("public input: {}", public_input.to_hex());

    // Partial verification
    let agg_proof = to_batch::<G1, KeccakFqSponge, KeccakFrSponge, KZGProof>(
        &verifier_index,
        &proof,
        &public_input_vec,
    )
    .unwrap();

    // Final verify
    let BatchEvaluationProof {
        sponge: _,
        evaluations,
        evaluation_points,
        polyscale,
        evalscale: _,
        opening,
        combined_inner_product: _,
    } = agg_proof;
    if !opening.verify(&index.srs, &evaluations, polyscale, &evaluation_points) {
        panic!();
    }

    let precomputed_tokens = precompute_evaluation(
        &index.linearization.constant_term,
        verifier_index.domain,
        &proof.evals,
        verifier_index.zk_rows,
    );

    // Serialize and write to binaries
    fs::write(
        "../eth_verifier/prover_proof.bin",
        EVMSerializableType(proof).to_bytes(),
    )
    .unwrap();
    fs::write(
        "../eth_verifier/verifier_index.mpk",
        rmp_serde::to_vec_named(&verifier_index).unwrap(),
    )
    .unwrap();
    fs::write(
        "../eth_verifier/verifier_index.bin",
        EVMSerializableType(verifier_index).to_bytes(),
    )
    .unwrap();
    let srs_to_serialize = PairingSRS::<Bn<Parameters>> {
        full_srs: SRS {
            g: index.srs.full_srs.g[0..3].to_vec(),
            h: index.srs.full_srs.h,
            lagrange_bases: HashMap::new(),
        },
        verifier_srs: index.srs.verifier_srs.clone(),
    };
    println!(
        "urs.g: {:?}",
        srs_to_serialize
            .full_srs
            .g
            .iter()
            .map(|g_i| g_i.to_string())
            .collect::<Vec<_>>()
    );
    println!("urs.h: {:?}", srs_to_serialize.full_srs.h.to_string());
    fs::write(
        "../eth_verifier/urs.mpk",
        rmp_serde::to_vec_named(&srs_to_serialize).unwrap(),
    )
    .unwrap();
    fs::write(
        "../eth_verifier/linearization.bin",
        EVMSerializableType(precomputed_tokens).to_bytes(),
    )
    .unwrap();

    let mut public_input_bytes = EVMSerializableType(*public_input).to_bytes();
    fs::write("../eth_verifier/public_input.bin", public_input_bytes).unwrap();

    let empty_polycomm = PolyComm::new(
        vec![G1::new(BaseField::from(0), BaseField::from(0), true)],
        None,
    );
    let mut lagrange_bases = index.srs.full_srs.lagrange_bases.clone();
    let lagrange_bases: HashMap<_, _> = lagrange_bases
        .iter_mut()
        .map(|(key, bases)| {
            bases.resize(1, empty_polycomm.clone());
            (key, bases)
        })
        .collect();
    fs::write(
        "../eth_verifier/lagrange_bases.mpk",
        rmp_serde::to_vec_named(&lagrange_bases).unwrap(),
    )
    .unwrap();

    // Serialize lagrange bases for hardcoding
    fs::write(
        "../eth_verifier/lagrange_bases.bin",
        EVMSerializableType(lagrange_bases[&domain_size].clone()).to_bytes(),
    )
    .unwrap();
}

fn precompute_evaluation(
    tokens: &Vec<BN254PolishToken>,
    d: Radix2EvaluationDomain<ark_ff::Fp256<ark_bn254::FrParameters>>,
    evals: &BN254ProofEvaluations,
    zk_rows: u64,
) -> Vec<BN254PolishToken> {
    let mut first_i = 0;
    let mut stack: Vec<BN254PolishToken> = Vec::with_capacity(3);
    let mut total_tokens = 0;

    let mut new_tokens = vec![];

    let constants = Constants {
        alpha: ScalarField::from(0),
        beta: ScalarField::from(0),
        gamma: ScalarField::from(0),
        joint_combiner: None,
        endo_coefficient: G1::endos().1,
        mds: &G1::sponge_params().mds,
        zk_rows,
    };
    let evals = evals.combine(&PointEvaluations {
        zeta: ScalarField::from(0),
        zeta_omega: ScalarField::from(0),
    });

    for token in tokens.clone().iter() {
        use PolishToken::*;
        let is_operation_token = matches!(token, Add | Mul | Sub | Pow(_) | Dup);
        let is_data_token = matches!(
            token,
            EndoCoefficient | Mds { row: _, col: _ } | Literal(_) | Cell(_)
        );

        match stack.len() {
            0 => {
                if is_data_token {
                    stack.push(token.clone());
                } else {
                    new_tokens.push(token.clone());
                }
            }
            1 => {
                if is_data_token {
                    stack.push(token.clone());
                } else {
                    new_tokens.append(&mut stack);
                    new_tokens.push(token.clone());
                }
            }
            2 => {
                if is_operation_token {
                    stack.push(token.clone());
                    let partial_eval =
                        partial_polish_evaluation(&stack, &evals, &constants).unwrap();
                    if partial_eval.len() == 3 {
                        new_tokens.extend(partial_eval);
                        stack.truncate(0);
                    } else {
                        stack = partial_eval;
                    }
                } else {
                    new_tokens.append(&mut stack);
                    if is_data_token {
                        stack.push(token.clone());
                    } else {
                        new_tokens.push(token.clone());
                    }
                }
            }
            _ => unreachable!(),
        }
    }
    println!("Token compression result: {}", 1. - new_tokens.len() as f64 / tokens.len() as f64);
    new_tokens
}

fn partial_polish_evaluation(
    tokens: &[BN254PolishToken],
    evals: &ProofEvaluations<PointEvaluations<ScalarField>>,
    c: &Constants<ScalarField>,
) -> Result<Vec<BN254PolishToken>, ExprError> {
    let mut stack = vec![];

    use PolishToken::*;
    for t in tokens.iter() {
        match t {
            EndoCoefficient => stack.push(c.endo_coefficient),
            Mds { row, col } => stack.push(c.mds[*row][*col]),
            Literal(x) => stack.push(*x),
            Dup => stack.push(stack[stack.len() - 1]),
            Cell(v) => stack.push(evaluate(v, evals).unwrap()),
            Pow(n) => {
                let i = stack.len() - 1;
                stack[i] = stack[i].pow([*n]);
            }
            Add => {
                let y = stack.pop().ok_or(ExprError::EmptyStack)?;
                let x = stack.pop().ok_or(ExprError::EmptyStack)?;
                stack.push(x + y);
            }
            Mul => {
                let y = stack.pop().ok_or(ExprError::EmptyStack)?;
                let x = stack.pop().ok_or(ExprError::EmptyStack)?;
                stack.push(x * y);
            }
            Sub => {
                let y = stack.pop().ok_or(ExprError::EmptyStack)?;
                let x = stack.pop().ok_or(ExprError::EmptyStack)?;
                stack.push(x - y);
            }
            _ => unreachable!(),
        }
    }

    assert!(stack.len() <= 3);
    Ok(stack.into_iter().map(Literal).collect())
}

fn evaluate(
    v: &Variable,
    evals: &ProofEvaluations<PointEvaluations<ScalarField>>,
) -> Result<ScalarField, ExprError> {
    let point_evaluations = {
        use Column::*;
        match v.col {
            Witness(i) => Ok(evals.w[i]),
            Z => Ok(evals.z),
            LookupSorted(i) => {
                evals.lookup_sorted[i].ok_or(ExprError::MissingIndexEvaluation(v.col))
            }
            LookupAggreg => evals
                .lookup_aggregation
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            LookupTable => evals
                .lookup_table
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            LookupRuntimeTable => evals
                .runtime_lookup_table
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::Poseidon) => Ok(evals.poseidon_selector),
            Index(GateType::Generic) => Ok(evals.generic_selector),
            Index(GateType::CompleteAdd) => Ok(evals.complete_add_selector),
            Index(GateType::VarBaseMul) => Ok(evals.mul_selector),
            Index(GateType::EndoMul) => Ok(evals.emul_selector),
            Index(GateType::EndoMulScalar) => Ok(evals.endomul_scalar_selector),
            Index(GateType::RangeCheck0) => evals
                .range_check0_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::RangeCheck1) => evals
                .range_check1_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::ForeignFieldAdd) => evals
                .foreign_field_add_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::ForeignFieldMul) => evals
                .foreign_field_mul_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::Xor16) => evals
                .xor_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(GateType::Rot64) => evals
                .rot_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Permutation(i) => Ok(evals.s[i]),
            Coefficient(i) => Ok(evals.coefficients[i]),
            Column::LookupKindIndex(LookupPattern::Xor) => evals
                .xor_lookup_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Column::LookupKindIndex(LookupPattern::Lookup) => evals
                .lookup_gate_lookup_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Column::LookupKindIndex(LookupPattern::RangeCheck) => evals
                .range_check_lookup_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Column::LookupKindIndex(LookupPattern::ForeignFieldMul) => evals
                .foreign_field_mul_lookup_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Column::LookupRuntimeSelector => evals
                .runtime_lookup_table_selector
                .ok_or(ExprError::MissingIndexEvaluation(v.col)),
            Index(_) => Err(ExprError::MissingIndexEvaluation(v.col)),
        }
    }?;
    match v.row {
        CurrOrNext::Curr => Ok(point_evaluations.zeta),
        CurrOrNext::Next => Ok(point_evaluations.zeta_omega),
    }
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

    // This seed (42) is also used for generating a trusted setup in Solidity.
    let x = ark_bn254::Fr::from(42);
    let mut srs = create_srs(x, cs.gates.len(), cs.domain);
    srs.full_srs.add_lagrange_basis(cs.domain.d1);

    let (_endo_q, endo_r) = G1::endos();
    let index = ProverIndex::<G1, KZGProof>::create(cs, *endo_r, Arc::new(srs.clone()));
    println!("cs endo: {}", endo_r); // ProverIndex::create() sets cs endo to endo_r

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

    println!(
        "verifier_index digest: {}",
        index.verifier_index().digest::<KeccakFqSponge>()
    );

    // Partially verify proof
    let public_inputs = vec![];
    let agg_proof = to_batch::<
        G1Affine,
        Keccak256FqSponge<BaseField, G1, ScalarField>,
        Keccak256FrSponge<ScalarField>,
        KZGProof,
    >(&index.verifier_index(), &proof, &public_inputs)
    .unwrap();

    // Final verify
    let BatchEvaluationProof {
        sponge: _,
        evaluations,
        evaluation_points,
        polyscale,
        evalscale: _,
        opening,
        combined_inner_product: _,
    } = agg_proof;
    if !opening.verify(&srs, &evaluations, polyscale, &evaluation_points) {
        panic!();
    }

    // Serialize and write to binaries
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
    let srs_to_serialize = PairingSRS::<Bn<Parameters>> {
        full_srs: SRS {
            g: srs.full_srs.g[0..3].to_vec(),
            h: srs.full_srs.h,
            lagrange_bases: HashMap::new(),
        },
        verifier_srs: srs.verifier_srs,
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
    variable: Variable,
}

#[derive(Serialize)]
struct Pow {
    pow: u64,
}

#[derive(Serialize)]
struct UnnormalizedLagrangeBasis {
    rowoffset: i32,
}

#[derive(Serialize)]
struct Load {
    load: usize,
}

fn serialize_linearization(linearization: Linearization<Vec<PolishToken<ScalarField>>>) -> Vec<u8> {
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
                _ => rmp_serde::to_vec_named(&UnitVariant {
                    variant: "not implemented",
                }),
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

fn generate_test_proof_for_demo() {
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
