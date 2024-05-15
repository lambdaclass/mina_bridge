use std::sync::Arc;

use ark_ff::Field;
use kimchi::circuits::constraints::ConstraintSystem;
use kimchi::circuits::expr::{Column, Constants, ExprError, PolishToken, Variable};
use kimchi::circuits::gate::{CircuitGate, CurrOrNext, GateType};
use kimchi::circuits::lookup::lookups::LookupPattern;
use kimchi::circuits::polynomials::range_check;
use kimchi::circuits::wires::Wire;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::{Fp, VestaParameters};
use kimchi::mina_poseidon::constants::PlonkSpongeConstantsKimchi;
use kimchi::mina_poseidon::sponge::{DefaultFqSponge, DefaultFrSponge};
use kimchi::poly_commitment::commitment::CommitmentCurve;
use kimchi::proof::{PointEvaluations, ProofEvaluations, ProverProof};
use kimchi::prover_index::ProverIndex;
use kimchi::verifier::verify;
use kimchi::{
    curve::KimchiCurve,
    mina_curves::pasta::Vesta,
    poly_commitment::{evaluation_proof::OpeningProof, srs::SRS},
    verifier_index::VerifierIndex,
};

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<VestaParameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fp, SpongeParams>;

type Curve = Vesta;
type ScalarField = Fp;

pub fn kimchi_verify(
    proof: &ProverProof<Curve, OpeningProof<Curve>>,
    verifier_index: &VerifierIndex<Curve, OpeningProof<Curve>>,
) -> bool {
    verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
        &<Curve as CommitmentCurve>::Map::setup(),
        verifier_index,
        proof,
        &Vec::new(),
    )
    .is_ok()
}

fn precompute_evaluation(
    tokens: &[PolishToken<ScalarField>],
    evals: &ProofEvaluations<PointEvaluations<Vec<ScalarField>>>,
    zk_rows: u64,
) -> Vec<PolishToken<ScalarField>> {
    let mut stack: Vec<PolishToken<ScalarField>> = Vec::with_capacity(3);

    let mut new_tokens = vec![];

    let constants = Constants {
        alpha: ScalarField::from(0),
        beta: ScalarField::from(0),
        gamma: ScalarField::from(0),
        joint_combiner: None,
        endo_coefficient: Curve::endos().1,
        mds: &Curve::sponge_params().mds,
        zk_rows,
    };
    let evals = evals.combine(&PointEvaluations {
        zeta: ScalarField::from(0),
        zeta_omega: ScalarField::from(0),
    });

    // The idea is that we assumed there're many segments in the token
    // vec that don't depend on any result from the verifier, so
    // we might as well precompute those segments and send the results
    // as `Literal` tokens.
    //
    // As an example consider we have a segment which is equivalent to
    // 10 + 5 + 9. Those are 5 tokens in total and two operations the
    // EVM verifier needs to deserialize and execute. We instead compute
    // that segment here and replace the 5 tokens with the result: 14.
    //
    // For this we'll have a stack of tokens and we'll fill it first with
    // two operands ("data tokens", so non operation tokens) and then with
    // an operation, we'll evaluate those 3 tokens, replace them with the
    // result and continue until we arrive at a token which we can't
    // evaluate in the prover side. At this step the stack has the results
    // of that evaluated segment.

    #[allow(unreachable_patterns)]
    for token in tokens.iter() {
        use PolishToken::*;
        let is_unary_operation_token = matches!(token, Pow(_) | Dup);
        let is_binary_operation_token = matches!(token, Add | Mul | Sub);
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
                stack.push(token.clone());
                if is_unary_operation_token {
                    partial_polish_evaluation(&mut stack, &evals, &constants).unwrap();
                } else if is_binary_operation_token | !is_data_token {
                    new_tokens.append(&mut stack);
                }
            }
            2.. => {
                stack.push(token.clone());
                if is_unary_operation_token | is_binary_operation_token {
                    partial_polish_evaluation(&mut stack, &evals, &constants).unwrap();
                } else if !is_data_token {
                    new_tokens.append(&mut stack);
                }
            }
            _ => unreachable!(),
        }
    }
    println!(
        "Token compression result: {}",
        1. - new_tokens.len() as f64 / tokens.len() as f64
    );
    new_tokens
}

#[allow(clippy::type_complexity)]
pub fn generate_test_proof() -> (
    ProverProof<Curve, OpeningProof<Curve>>,
    VerifierIndex<Curve, OpeningProof<Curve>>,
    SRS<Curve>,
) {
    // Create range-check gadget
    let (mut next_row, mut gates) = CircuitGate::<ScalarField>::create_multi_range_check(0);

    // Create witness
    let witness = range_check::witness::create_multi::<ScalarField>(
        ScalarField::from(1),
        ScalarField::from(1),
        ScalarField::from(1),
    );

    // Temporary workaround for lookup-table/domain-size issue
    for _ in 0..1 {
        gates.push(CircuitGate::zero(Wire::for_row(next_row)));
        next_row += 1;
    }
    // Create constraint system
    let cs = ConstraintSystem::<ScalarField>::create(gates)
        //.lookup(vec![range_check::gadget::lookup_table()])
        .build()
        .unwrap();

    let mut srs = SRS::create_trusted_setup(ScalarField::from(42), cs.gates.len());
    srs.add_lagrange_basis(cs.domain.d1);

    let (_endo_q, endo_r) = Curve::endos();
    let index =
        ProverIndex::<Curve, OpeningProof<Curve>>::create(cs, *endo_r, Arc::new(srs.clone()));

    let group_map = <Curve as CommitmentCurve>::Map::setup();
    let proof = ProverProof::create_recursive::<BaseSponge, ScalarSponge>(
        &group_map,
        witness,
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();

    let mut verifier_index = index.clone().verifier_index();

    verifier_index.linearization.constant_term = precompute_evaluation(
        &verifier_index.linearization.constant_term,
        &proof.evals,
        verifier_index.zk_rows,
    );

    // Verify
    assert!(
        verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
            &group_map,
            &verifier_index,
            &proof,
            &Vec::new()
        )
        .is_ok(),
        "Generated test proof isn't valid."
    );

    (proof, verifier_index, srs)
}

fn partial_polish_evaluation(
    tokens: &mut Vec<PolishToken<ScalarField>>,
    evals: &ProofEvaluations<PointEvaluations<ScalarField>>,
    c: &Constants<ScalarField>,
) -> Result<(), ExprError> {
    let mut stack = vec![];

    use PolishToken::*;
    for t in tokens.iter() {
        match t {
            EndoCoefficient => stack.push(c.endo_coefficient),
            Mds { row, col } => stack.push(c.mds[*row][*col]),
            Literal(x) => stack.push(*x),
            Dup => stack.push(stack[stack.len() - 1]),
            Cell(v) => stack.push(evaluate_variable(v, evals)?),
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

    *tokens = stack.into_iter().map(Literal).collect();
    Ok(())
}

/// Function taken from proof_system's expr.rs because its private.
fn evaluate_variable(
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

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_generate_proof() {
        let (proof, verifier_index, srs) = generate_test_proof();
        println!("SRS size: {}", srs.g.len());
        for key in srs.lagrange_bases.keys() {
            println!("Lagrange bases size: {}", srs.lagrange_bases[key].len());
        }

        /*
            SRS and lagrange bases don't implement serde, so we need to
            pass them as inputs separately.
            In the test this has no effect but the code is there to reflect
            what is needed to do inside the SP1 script.

            ```rust
            srs.lagrange_bases = srs.lagrange_bases;
            verifier_index.srs = Arc::new(srs);
            ```
        */

        assert!(kimchi_verify(&proof, &verifier_index));
    }
}
