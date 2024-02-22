use ark_ec::AffineCurve;
use ark_ff::{Field, One, PrimeField};
use ark_poly::{EvaluationDomain, Polynomial};
/// This copies the `to_batch()` function from Mina's proof-systems project,
/// that will be used for testing purposes as the original function is private.
use kimchi::{
    circuits::{
        argument::ArgumentType,
        berkeley_columns::Column,
        constraints::ConstraintSystem,
        expr::{Constants, PolishToken},
        gate::GateType,
        lookup::{lookups::LookupPattern, tables::combine_table},
        polynomials::permutation,
        wires::{COLUMNS, PERMUTS},
    },
    curve::KimchiCurve,
    error::VerifyError,
    oracles::OraclesResult,
    plonk_sponge::FrSponge,
    proof::{PointEvaluations, ProofEvaluations, ProverProof},
    verifier::{Context, Result},
    verifier_index::VerifierIndex,
};
use mina_poseidon::FqSponge;
use poly_commitment::{
    commitment::{BatchEvaluationProof, Evaluation, PolyComm},
    OpenProof, SRS as _,
};

/// Enforce the length of evaluations inside [`Proof`].
/// Atm, the length of evaluations(both `zeta` and `zeta_omega`) SHOULD be 1.
/// The length value is prone to future change.
fn check_proof_evals_len<G, OpeningProof>(
    proof: &ProverProof<G, OpeningProof>,
    expected_size: usize,
) -> Result<()>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    let ProofEvaluations {
        public,
        w,
        z,
        s,
        coefficients,
        generic_selector,
        poseidon_selector,
        complete_add_selector,
        mul_selector,
        emul_selector,
        endomul_scalar_selector,
        range_check0_selector,
        range_check1_selector,
        foreign_field_add_selector,
        foreign_field_mul_selector,
        xor_selector,
        rot_selector,
        lookup_aggregation,
        lookup_table,
        lookup_sorted,
        runtime_lookup_table,
        runtime_lookup_table_selector,
        xor_lookup_selector,
        lookup_gate_lookup_selector,
        range_check_lookup_selector,
        foreign_field_mul_lookup_selector,
    } = &proof.evals;

    let check_eval_len = |eval: &PointEvaluations<Vec<_>>, str: &'static str| -> Result<()> {
        if eval.zeta.len() != expected_size {
            Err(VerifyError::IncorrectEvaluationsLength(
                expected_size,
                eval.zeta.len(),
                str,
            ))
        } else if eval.zeta_omega.len() != expected_size {
            Err(VerifyError::IncorrectEvaluationsLength(
                expected_size,
                eval.zeta_omega.len(),
                str,
            ))
        } else {
            Ok(())
        }
    };

    if let Some(public) = public {
        check_eval_len(public, "public input")?;
    }

    for w_i in w {
        check_eval_len(w_i, "witness")?;
    }
    check_eval_len(z, "permutation accumulator")?;
    for s_i in s {
        check_eval_len(s_i, "permutation shifts")?;
    }
    for coeff in coefficients {
        check_eval_len(coeff, "coefficients")?;
    }

    // Lookup evaluations
    for sorted in lookup_sorted.iter().flatten() {
        check_eval_len(sorted, "lookup sorted")?
    }

    if let Some(lookup_aggregation) = lookup_aggregation {
        check_eval_len(lookup_aggregation, "lookup aggregation")?;
    }
    if let Some(lookup_table) = lookup_table {
        check_eval_len(lookup_table, "lookup table")?;
    }
    if let Some(runtime_lookup_table) = runtime_lookup_table {
        check_eval_len(runtime_lookup_table, "runtime lookup table")?;
    }

    check_eval_len(generic_selector, "generic selector")?;
    check_eval_len(poseidon_selector, "poseidon selector")?;
    check_eval_len(complete_add_selector, "complete add selector")?;
    check_eval_len(mul_selector, "mul selector")?;
    check_eval_len(emul_selector, "endomul selector")?;
    check_eval_len(endomul_scalar_selector, "endomul scalar selector")?;

    // Optional gates

    if let Some(range_check0_selector) = range_check0_selector {
        check_eval_len(range_check0_selector, "range check 0 selector")?
    }
    if let Some(range_check1_selector) = range_check1_selector {
        check_eval_len(range_check1_selector, "range check 1 selector")?
    }
    if let Some(foreign_field_add_selector) = foreign_field_add_selector {
        check_eval_len(foreign_field_add_selector, "foreign field add selector")?
    }
    if let Some(foreign_field_mul_selector) = foreign_field_mul_selector {
        check_eval_len(foreign_field_mul_selector, "foreign field mul selector")?
    }
    if let Some(xor_selector) = xor_selector {
        check_eval_len(xor_selector, "xor selector")?
    }
    if let Some(rot_selector) = rot_selector {
        check_eval_len(rot_selector, "rot selector")?
    }

    // Lookup selectors

    if let Some(runtime_lookup_table_selector) = runtime_lookup_table_selector {
        check_eval_len(
            runtime_lookup_table_selector,
            "runtime lookup table selector",
        )?
    }
    if let Some(xor_lookup_selector) = xor_lookup_selector {
        check_eval_len(xor_lookup_selector, "xor lookup selector")?
    }
    if let Some(lookup_gate_lookup_selector) = lookup_gate_lookup_selector {
        check_eval_len(lookup_gate_lookup_selector, "lookup gate lookup selector")?
    }
    if let Some(range_check_lookup_selector) = range_check_lookup_selector {
        check_eval_len(range_check_lookup_selector, "range check lookup selector")?
    }
    if let Some(foreign_field_mul_lookup_selector) = foreign_field_mul_lookup_selector {
        check_eval_len(
            foreign_field_mul_lookup_selector,
            "foreign field mul lookup selector",
        )?
    }

    Ok(())
}

pub fn to_batch<'a, G, EFqSponge, EFrSponge, OpeningProof: OpenProof<G>>(
    verifier_index: &VerifierIndex<G, OpeningProof>,
    proof: &'a ProverProof<G, OpeningProof>,
    public_input: &'a [<G as AffineCurve>::ScalarField],
) -> Result<BatchEvaluationProof<'a, G, EFqSponge, OpeningProof>>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
    EFqSponge: Clone + FqSponge<G::BaseField, G, G::ScalarField>,
    EFrSponge: FrSponge<G::ScalarField>,
{
    //~
    //~ #### Partial verification
    //~
    //~ For every proof we want to verify, we defer the proof opening to the very end.
    //~ This allows us to potentially batch verify a number of partially verified proofs.
    //~ Essentially, this steps verifies that $f(\zeta) = t(\zeta) * Z_H(\zeta)$.
    //~

    let zk_rows = verifier_index.zk_rows;

    if proof.prev_challenges.len() != verifier_index.prev_challenges {
        return Err(VerifyError::IncorrectPrevChallengesLength(
            verifier_index.prev_challenges,
            proof.prev_challenges.len(),
        ));
    }
    if public_input.len() != verifier_index.public {
        return Err(VerifyError::IncorrectPubicInputLength(
            verifier_index.public,
        ));
    }

    //~ 1. Check the length of evaluations inside the proof.
    let chunk_size = {
        let d1_size = verifier_index.domain.size();
        if d1_size < verifier_index.max_poly_size {
            1
        } else {
            d1_size / verifier_index.max_poly_size
        }
    };
    check_proof_evals_len(proof, chunk_size)?;

    //~ 1. Commit to the negated public input polynomial.
    let public_comm = {
        if public_input.len() != verifier_index.public {
            return Err(VerifyError::IncorrectPubicInputLength(
                verifier_index.public,
            ));
        }
        let lgr_comm = verifier_index
            .srs()
            .get_lagrange_basis(verifier_index.domain.size())
            .expect("pre-computed committed lagrange bases not found");
        let com: Vec<_> = lgr_comm.iter().take(verifier_index.public).collect();
        if public_input.is_empty() {
            PolyComm::new(
                vec![verifier_index.srs().blinding_commitment(); chunk_size],
                None,
            )
        } else {
            let elm: Vec<_> = public_input.iter().map(|s| -*s).collect();
            let public_comm = PolyComm::<G>::multi_scalar_mul(&com, &elm);
            verifier_index
                .srs()
                .mask_custom(
                    public_comm.clone(),
                    &public_comm.map(|_| G::ScalarField::one()),
                )
                .unwrap()
                .commitment
        }
    };

    //~ 1. Run the [Fiat-Shamir argument](#fiat-shamir-argument).
    let OraclesResult {
        fq_sponge,
        oracles,
        all_alphas,
        public_evals,
        powers_of_eval_points_for_chunks,
        polys,
        zeta1: zeta_to_domain_size,
        ft_eval0,
        combined_inner_product,
        ..
    } = proof.oracles::<EFqSponge, EFrSponge>(verifier_index, &public_comm, Some(public_input))?;

    //~ 1. Combine the chunked polynomials' evaluations
    //~    (TODO: most likely only the quotient polynomial is chunked)
    //~    with the right powers of $\zeta^n$ and $(\zeta * \omega)^n$.
    let evals = proof.evals.combine(&powers_of_eval_points_for_chunks);

    let context = Context {
        verifier_index,
        proof,
        public_input,
    };

    //~ 1. Compute the commitment to the linearized polynomial $f$.
    //~    To do this, add the constraints of all of the gates, of the permutation,
    //~    and optionally of the lookup.
    //~    (See the separate sections in the [constraints](#constraints) section.)
    //~    Any polynomial should be replaced by its associated commitment,
    //~    contained in the verifier index or in the proof,
    //~    unless a polynomial has its evaluation provided by the proof
    //~    in which case the evaluation should be used in place of the commitment.
    let f_comm = {
        // the permutation is written manually (not using the expr framework)
        let permutation_vanishing_polynomial = verifier_index
            .permutation_vanishing_polynomial_m()
            .evaluate(&oracles.zeta);

        let alphas = all_alphas.get_alphas(ArgumentType::Permutation, permutation::CONSTRAINTS);

        let mut commitments = vec![&verifier_index.sigma_comm[PERMUTS - 1]];
        let mut scalars = vec![ConstraintSystem::<G::ScalarField>::perm_scalars(
            &evals,
            oracles.beta,
            oracles.gamma,
            alphas,
            permutation_vanishing_polynomial,
        )];

        // other gates are implemented using the expression framework
        {
            // TODO: Reuse constants from oracles function
            let constants = Constants {
                alpha: oracles.alpha,
                beta: oracles.beta,
                gamma: oracles.gamma,
                joint_combiner: oracles.joint_combiner.as_ref().map(|j| j.1),
                endo_coefficient: verifier_index.endo,
                mds: &G::sponge_params().mds,
                zk_rows,
            };

            for (col, tokens) in &verifier_index.linearization.index_terms {
                let scalar = PolishToken::evaluate(
                    tokens,
                    verifier_index.domain,
                    oracles.zeta,
                    &evals,
                    &constants,
                )
                .expect("should evaluate");

                let col = *col;
                scalars.push(scalar);
                commitments.push(
                    context
                        .get_column(col)
                        .ok_or(VerifyError::MissingCommitment(col))?,
                );
            }
        }

        // MSM
        PolyComm::multi_scalar_mul(&commitments, &scalars)
    };

    //~ 1. Compute the (chuncked) commitment of $ft$
    //~    (see [Maller's optimization](../crypto/plonk/maller_15.html)).
    let ft_comm = {
        let zeta_to_srs_len = oracles.zeta.pow([verifier_index.max_poly_size as u64]);
        let chunked_f_comm = f_comm.chunk_commitment(zeta_to_srs_len);
        let chunked_t_comm = &proof.commitments.t_comm.chunk_commitment(zeta_to_srs_len);
        &chunked_f_comm - &chunked_t_comm.scale(zeta_to_domain_size - G::ScalarField::one())
    };

    //~ 1. List the polynomial commitments, and their associated evaluations,
    //~    that are associated to the aggregated evaluation proof in the proof:
    let mut evaluations = vec![];

    //~~ * recursion
    evaluations.extend(polys.into_iter().map(|(c, e)| Evaluation {
        commitment: c,
        evaluations: e,
        degree_bound: None,
    }));

    //~~ * public input commitment
    evaluations.push(Evaluation {
        commitment: public_comm,
        evaluations: public_evals.to_vec(),
        degree_bound: None,
    });

    //~~ * ft commitment (chunks of it)
    evaluations.push(Evaluation {
        commitment: ft_comm,
        evaluations: vec![vec![ft_eval0], vec![proof.ft_eval1]],
        degree_bound: None,
    });

    for col in [
        //~~ * permutation commitment
        Column::Z,
        //~~ * index commitments that use the coefficients
        Column::Index(GateType::Generic),
        Column::Index(GateType::Poseidon),
        Column::Index(GateType::CompleteAdd),
        Column::Index(GateType::VarBaseMul),
        Column::Index(GateType::EndoMul),
        Column::Index(GateType::EndoMulScalar),
    ]
    .into_iter()
    //~~ * witness commitments
    .chain((0..COLUMNS).map(Column::Witness))
    //~~ * coefficient commitments
    .chain((0..COLUMNS).map(Column::Coefficient))
    //~~ * sigma commitments
    .chain((0..PERMUTS - 1).map(Column::Permutation))
    //~~ * optional gate commitments
    .chain(
        verifier_index
            .range_check0_comm
            .as_ref()
            .map(|_| Column::Index(GateType::RangeCheck0)),
    )
    .chain(
        verifier_index
            .range_check1_comm
            .as_ref()
            .map(|_| Column::Index(GateType::RangeCheck1)),
    )
    .chain(
        verifier_index
            .foreign_field_add_comm
            .as_ref()
            .map(|_| Column::Index(GateType::ForeignFieldAdd)),
    )
    .chain(
        verifier_index
            .foreign_field_mul_comm
            .as_ref()
            .map(|_| Column::Index(GateType::ForeignFieldMul)),
    )
    .chain(
        verifier_index
            .xor_comm
            .as_ref()
            .map(|_| Column::Index(GateType::Xor16)),
    )
    .chain(
        verifier_index
            .rot_comm
            .as_ref()
            .map(|_| Column::Index(GateType::Rot64)),
    )
    //~~ * lookup commitments
    //~
    .chain(
        verifier_index
            .lookup_index
            .as_ref()
            .map(|li| {
                // add evaluations of sorted polynomials
                (0..li.lookup_info.max_per_row + 1)
                    .map(Column::LookupSorted)
                    // add evaluations of the aggreg polynomial
                    .chain([Column::LookupAggreg].into_iter())
            })
            .into_iter()
            .flatten(),
    ) {
        let evals = proof
            .evals
            .get_column(col)
            .ok_or(VerifyError::MissingEvaluation(col))?;
        evaluations.push(Evaluation {
            commitment: context
                .get_column(col)
                .ok_or(VerifyError::MissingCommitment(col))?
                .clone(),
            evaluations: vec![evals.zeta.clone(), evals.zeta_omega.clone()],
            degree_bound: None,
        });
    }

    if let Some(li) = &verifier_index.lookup_index {
        let lookup_comms = proof
            .commitments
            .lookup
            .as_ref()
            .ok_or(VerifyError::LookupCommitmentMissing)?;

        let lookup_table = proof
            .evals
            .lookup_table
            .as_ref()
            .ok_or(VerifyError::LookupEvalsMissing)?;
        let runtime_lookup_table = proof.evals.runtime_lookup_table.as_ref();

        // compute table commitment
        let table_comm = {
            let joint_combiner = oracles
                .joint_combiner
                .expect("joint_combiner should be present if lookups are used");
            let table_id_combiner = joint_combiner
                .1
                .pow([u64::from(li.lookup_info.max_joint_size)]);
            let lookup_table: Vec<_> = li.lookup_table.iter().collect();
            let runtime = lookup_comms.runtime.as_ref();

            combine_table(
                &lookup_table,
                joint_combiner.1,
                table_id_combiner,
                li.table_ids.as_ref(),
                runtime,
            )
        };

        // add evaluation of the table polynomial
        evaluations.push(Evaluation {
            commitment: table_comm,
            evaluations: vec![lookup_table.zeta.clone(), lookup_table.zeta_omega.clone()],
            degree_bound: None,
        });

        // add evaluation of the runtime table polynomial
        if li.runtime_tables_selector.is_some() {
            let runtime = lookup_comms
                .runtime
                .as_ref()
                .ok_or(VerifyError::IncorrectRuntimeProof)?;
            let runtime_eval = runtime_lookup_table
                .as_ref()
                .map(|x| x.map_ref(&|x| x.clone()))
                .ok_or(VerifyError::IncorrectRuntimeProof)?;

            evaluations.push(Evaluation {
                commitment: runtime.clone(),
                evaluations: vec![runtime_eval.zeta, runtime_eval.zeta_omega],
                degree_bound: None,
            });
        }
    }

    for col in verifier_index
        .lookup_index
        .as_ref()
        .map(|li| {
            (li.runtime_tables_selector
                .as_ref()
                .map(|_| Column::LookupRuntimeSelector))
            .into_iter()
            .chain(
                li.lookup_selectors
                    .xor
                    .as_ref()
                    .map(|_| Column::LookupKindIndex(LookupPattern::Xor)),
            )
            .chain(
                li.lookup_selectors
                    .lookup
                    .as_ref()
                    .map(|_| Column::LookupKindIndex(LookupPattern::Lookup)),
            )
            .chain(
                li.lookup_selectors
                    .range_check
                    .as_ref()
                    .map(|_| Column::LookupKindIndex(LookupPattern::RangeCheck)),
            )
            .chain(
                li.lookup_selectors
                    .ffmul
                    .as_ref()
                    .map(|_| Column::LookupKindIndex(LookupPattern::ForeignFieldMul)),
            )
        })
        .into_iter()
        .flatten()
    {
        let evals = proof
            .evals
            .get_column(col)
            .ok_or(VerifyError::MissingEvaluation(col))?;
        evaluations.push(Evaluation {
            commitment: context
                .get_column(col)
                .ok_or(VerifyError::MissingCommitment(col))?
                .clone(),
            evaluations: vec![evals.zeta.clone(), evals.zeta_omega.clone()],
            degree_bound: None,
        });
    }

    // prepare for the opening proof verification
    let evaluation_points = vec![oracles.zeta, oracles.zeta * verifier_index.domain.group_gen];
    Ok(BatchEvaluationProof {
        sponge: fq_sponge,
        evaluations,
        evaluation_points,
        polyscale: oracles.v,
        evalscale: oracles.u,
        opening: &proof.proof,
        combined_inner_product,
    })
}
