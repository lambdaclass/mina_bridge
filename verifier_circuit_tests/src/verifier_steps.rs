use ark_ec::AffineCurve;
use ark_ff::{Field, One, PrimeField, Zero};
use ark_poly::{univariate::DensePolynomial, EvaluationDomain, Polynomial};
use kimchi::{
    circuits::{
        argument::ArgumentType,
        expr::{Column, Constants, PolishToken},
        gate::GateType,
        lookup::lookups::LookupPattern,
        polynomials::permutation,
        scalars::RandomOracles,
        wires::{COLUMNS, PERMUTS},
    },
    curve::KimchiCurve,
    error::VerifyError,
    mina_poseidon::{sponge::ScalarChallenge, FqSponge},
    o1_utils::ExtendedDensePolynomial,
    oracles::OraclesResult,
    plonk_sponge::FrSponge,
    poly_commitment::{
        commitment::{absorb_commitment, combined_inner_product},
        OpenProof, PolyComm, SRS,
    },
    proof::{PointEvaluations, ProofEvaluations, ProverProof, RecursionChallenge},
    verifier_index::VerifierIndex,
};

/// Enforce the length of evaluations inside [`Proof`].
/// Atm, the length of evaluations(both `zeta` and `zeta_omega`) SHOULD be 1.
/// The length value is prone to future change.
pub fn check_proof_evals_len<G, OpeningProof>(
    proof: &ProverProof<G, OpeningProof>,
    expected_size: usize,
) -> Result<(), VerifyError>
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

    let check_eval_len =
        |eval: &PointEvaluations<Vec<_>>, str: &'static str| -> Result<(), VerifyError> {
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

/// Execute step 1 of partial verification
pub fn to_batch_step1<G, OpeningProof: OpenProof<G>>(
    proof: &ProverProof<G, OpeningProof>,
    verifier_index: &VerifierIndex<G, OpeningProof>,
) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    let chunk_size = {
        let d1_size = verifier_index.domain.size();
        if d1_size < verifier_index.max_poly_size {
            1
        } else {
            d1_size / verifier_index.max_poly_size
        }
    };
    println!("to_batch(), step 1: Check evals len.");
    check_proof_evals_len(proof, chunk_size)?;
    Ok(())
}

/// Execute step 2 of partial verification
pub fn to_batch_step2<G, OpeningProof: OpenProof<G>>(
    verifier_index: &VerifierIndex<G, OpeningProof>,
    public_input: &[<G as AffineCurve>::ScalarField],
) -> Result<PolyComm<G>, VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    println!("to_batch(), step 2: Commit to the negated public input polynomial.");
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
        let elm: Vec<_> = public_input.iter().map(|s| -*s).collect();
        let public_comm = PolyComm::<G>::multi_scalar_mul(&com, &elm);
        verifier_index
            .srs()
            .mask_custom(
                public_comm,
                &PolyComm {
                    unshifted: vec![G::ScalarField::one(); 1],
                    shifted: None,
                },
            )
            .unwrap()
            .commitment
    };
    println!(
        "Done, public_comm: {:?}",
        public_comm.unshifted[0].to_string()
    );
    Ok(public_comm)
}

pub fn to_batch_step3<G, EFqSponge, EFrSponge, OpeningProof>(
    proof: &ProverProof<G, OpeningProof>,
    index: &VerifierIndex<G, OpeningProof>,
    public_comm: &PolyComm<G>,
    public_input: Option<&[G::ScalarField]>,
) -> Result<OraclesResult<G, EFqSponge>, VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
    EFqSponge: Clone + FqSponge<G::BaseField, G, G::ScalarField>,
    EFrSponge: FrSponge<G::ScalarField>,
    OpeningProof: OpenProof<G>,
{
    //~
    //~ #### Fiat-Shamir argument
    //~
    //~ We run the following algorithm:
    //~
    let n = index.domain.size;
    let (_, endo_r) = G::endos();

    let chunk_size = {
        let d1_size = index.domain.size();
        if d1_size < index.max_poly_size {
            1
        } else {
            d1_size / index.max_poly_size
        }
    };

    let zk_rows = index.zk_rows;

    //~ 1. Setup the Fq-Sponge.
    let mut fq_sponge = EFqSponge::new(G::other_curve_sponge_params());

    //~ 1. Absorb the digest of the VerifierIndex.
    let verifier_index_digest = index.digest::<EFqSponge>();
    fq_sponge.absorb_fq(&[verifier_index_digest]);

    //~ 1. Absorb the commitments of the previous challenges with the Fq-sponge.
    for RecursionChallenge { comm, .. } in &proof.prev_challenges {
        absorb_commitment(&mut fq_sponge, comm);
    }

    //~ 1. Absorb the commitment of the public input polynomial with the Fq-Sponge.
    absorb_commitment(&mut fq_sponge, public_comm);

    //~ 1. Absorb the commitments to the registers / witness columns with the Fq-Sponge.
    proof
        .commitments
        .w_comm
        .iter()
        .for_each(|c| absorb_commitment(&mut fq_sponge, c));

    //~ 1. If lookup is used:
    if let Some(l) = &index.lookup_index {
        let lookup_commits = proof
            .commitments
            .lookup
            .as_ref()
            .ok_or(VerifyError::LookupCommitmentMissing)?;

        // if runtime is used, absorb the commitment
        if l.runtime_tables_selector.is_some() {
            let runtime_commit = lookup_commits
                .runtime
                .as_ref()
                .ok_or(VerifyError::IncorrectRuntimeProof)?;
            absorb_commitment(&mut fq_sponge, runtime_commit);
        }
    }

    let joint_combiner = if let Some(l) = &index.lookup_index {
        //~~ * If it involves queries to a multiple-column lookup table,
        //~~   then squeeze the Fq-Sponge to obtain the joint combiner challenge $j'$,
        //~~   otherwise set the joint combiner challenge $j'$ to $0$.
        let joint_combiner = if l.joint_lookup_used {
            fq_sponge.challenge()
        } else {
            G::ScalarField::zero()
        };

        //~~ * Derive the scalar joint combiner challenge $j$ from $j'$ using the endomorphism.
        //~~   (TODO: specify endomorphism)
        let joint_combiner = ScalarChallenge(joint_combiner);
        let joint_combiner_field = joint_combiner.to_field(endo_r);
        let joint_combiner = (joint_combiner, joint_combiner_field);

        Some(joint_combiner)
    } else {
        None
    };

    if index.lookup_index.is_some() {
        let lookup_commits = proof
            .commitments
            .lookup
            .as_ref()
            .ok_or(VerifyError::LookupCommitmentMissing)?;

        //~~ * absorb the commitments to the sorted polynomials.
        for com in &lookup_commits.sorted {
            absorb_commitment(&mut fq_sponge, com);
        }
    }

    //~ 1. Sample $\beta$ with the Fq-Sponge.
    let beta = fq_sponge.challenge();

    //~ 1. Sample $\gamma$ with the Fq-Sponge.
    let gamma = fq_sponge.challenge();

    //~ 1. If using lookup, absorb the commitment to the aggregation lookup polynomial.
    proof.commitments.lookup.iter().for_each(|l| {
        absorb_commitment(&mut fq_sponge, &l.aggreg);
    });

    //~ 1. Absorb the commitment to the permutation trace with the Fq-Sponge.
    absorb_commitment(&mut fq_sponge, &proof.commitments.z_comm);

    //~ 1. Sample $\alpha'$ with the Fq-Sponge.
    let alpha_chal = ScalarChallenge(fq_sponge.challenge());

    //~ 1. Derive $\alpha$ from $\alpha'$ using the endomorphism (TODO: details).
    let alpha = alpha_chal.to_field(endo_r);

    //~ 1. Enforce that the length of the $t$ commitment is of size 7.
    if proof.commitments.t_comm.unshifted.len() > chunk_size * 7 {
        return Err(VerifyError::IncorrectCommitmentLength(
            "t",
            chunk_size * 7,
            proof.commitments.t_comm.unshifted.len(),
        ));
    }

    //~ 1. Absorb the commitment to the quotient polynomial $t$ into the argument.
    absorb_commitment(&mut fq_sponge, &proof.commitments.t_comm);

    //~ 1. Sample $\zeta'$ with the Fq-Sponge.
    let zeta_chal = ScalarChallenge(fq_sponge.challenge());

    //~ 1. Derive $\zeta$ from $\zeta'$ using the endomorphism (TODO: specify).
    let zeta = zeta_chal.to_field(endo_r);

    //~ 1. Setup the Fr-Sponge.
    let digest = fq_sponge.clone().digest();
    let mut fr_sponge = EFrSponge::new(G::sponge_params());

    //~ 1. Squeeze the Fq-sponge and absorb the result with the Fr-Sponge.
    fr_sponge.absorb(&digest);

    //~ 1. Absorb the previous recursion challenges.
    let prev_challenge_digest = {
        // Note: we absorb in a new sponge here to limit the scope in which we need the
        // more-expensive 'optional sponge'.
        let mut fr_sponge = EFrSponge::new(G::sponge_params());
        for RecursionChallenge { chals, .. } in &proof.prev_challenges {
            fr_sponge.absorb_multiple(chals);
        }
        fr_sponge.digest()
    };
    fr_sponge.absorb(&prev_challenge_digest);

    // prepare some often used values
    let zeta1 = zeta.pow([n]);
    let zetaw = zeta * index.domain.group_gen;
    let evaluation_points = [zeta, zetaw];
    let powers_of_eval_points_for_chunks = PointEvaluations {
        zeta: zeta.pow([index.max_poly_size as u64]),
        zeta_omega: zetaw.pow([index.max_poly_size as u64]),
    };

    //~ 1. Compute evaluations for the previous recursion challenges.
    let polys: Vec<(PolyComm<G>, _)> = proof
        .prev_challenges
        .iter()
        .map(|challenge| {
            let evals = challenge.evals(
                index.max_poly_size,
                &evaluation_points,
                &[
                    powers_of_eval_points_for_chunks.zeta,
                    powers_of_eval_points_for_chunks.zeta_omega,
                ],
            );
            let RecursionChallenge { chals: _, comm } = challenge;
            (comm.clone(), evals)
        })
        .collect();

    // retrieve ranges for the powers of alphas
    let mut all_alphas = index.powers_of_alpha.clone();
    all_alphas.instantiate(alpha);

    let public_evals = if let Some(public_evals) = &proof.evals.public {
        [public_evals.zeta.clone(), public_evals.zeta_omega.clone()]
    } else if chunk_size > 1 {
        return Err(VerifyError::MissingPublicInputEvaluation);
    } else if let Some(public_input) = public_input {
        // compute Lagrange base evaluation denominators
        let w: Vec<_> = index.domain.elements().take(public_input.len()).collect();

        let mut zeta_minus_x: Vec<_> = w.iter().map(|w| zeta - w).collect();

        w.iter()
            .take(public_input.len())
            .for_each(|w| zeta_minus_x.push(zetaw - w));

        ark_ff::fields::batch_inversion::<G::ScalarField>(&mut zeta_minus_x);

        //~ 1. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
        //~
        //~    NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
        if public_input.is_empty() {
            [vec![G::ScalarField::zero()], vec![G::ScalarField::zero()]]
        } else {
            [
                vec![
                    (public_input
                        .iter()
                        .zip(zeta_minus_x.iter())
                        .zip(index.domain.elements())
                        .map(|((p, l), w)| -*l * p * w)
                        .fold(G::ScalarField::zero(), |x, y| x + y))
                        * (zeta1 - G::ScalarField::one())
                        * index.domain.size_inv,
                ],
                vec![
                    (public_input
                        .iter()
                        .zip(zeta_minus_x[public_input.len()..].iter())
                        .zip(index.domain.elements())
                        .map(|((p, l), w)| -*l * p * w)
                        .fold(G::ScalarField::zero(), |x, y| x + y))
                        * index.domain.size_inv
                        * (zetaw.pow([n]) - G::ScalarField::one()),
                ],
            ]
        }
    } else {
        return Err(VerifyError::MissingPublicInputEvaluation);
    };

    //~ 1. Absorb the unique evaluation of ft: $ft(\zeta\omega)$.
    fr_sponge.absorb(&proof.ft_eval1);

    //~ 1. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
    //~~ * the public polynomial
    //~~ * z
    //~~ * generic selector
    //~~ * poseidon selector
    //~~ * the 15 register/witness
    //~~ * 6 sigmas evaluations (the last one is not evaluated)
    fr_sponge.absorb_multiple(&public_evals[0]);
    fr_sponge.absorb_multiple(&public_evals[1]);
    fr_sponge.absorb_evaluations(&proof.evals);

    //~ 1. Sample $v'$ with the Fr-Sponge.
    let v_chal = fr_sponge.challenge();

    //~ 1. Derive $v$ from $v'$ using the endomorphism (TODO: specify).
    let v = v_chal.to_field(endo_r);

    //~ 1. Sample $u'$ with the Fr-Sponge.
    let u_chal = fr_sponge.challenge();

    //~ 1. Derive $u$ from $u'$ using the endomorphism (TODO: specify).
    let u = u_chal.to_field(endo_r);

    //~ 1. Create a list of all polynomials that have an evaluation proof.

    let evals = proof.evals.combine(&powers_of_eval_points_for_chunks);

    //~ 1. Compute the evaluation of $ft(\zeta)$.
    let ft_eval0 = {
        let permutation_vanishing_polynomial =
            index.permutation_vanishing_polynomial_m().evaluate(&zeta);
        let zeta1m1 = zeta1 - G::ScalarField::one();

        let mut alpha_powers =
            all_alphas.get_alphas(ArgumentType::Permutation, permutation::CONSTRAINTS);
        let alpha0 = alpha_powers
            .next()
            .expect("missing power of alpha for permutation");
        let alpha1 = alpha_powers
            .next()
            .expect("missing power of alpha for permutation");
        let alpha2 = alpha_powers
            .next()
            .expect("missing power of alpha for permutation");

        let init = (evals.w[PERMUTS - 1].zeta + gamma)
            * evals.z.zeta_omega
            * alpha0
            * permutation_vanishing_polynomial;
        let mut ft_eval0 = evals
            .w
            .iter()
            .zip(evals.s.iter())
            .map(|(w, s)| (beta * s.zeta) + w.zeta + gamma)
            .fold(init, |x, y| x * y);

        ft_eval0 -= DensePolynomial::eval_polynomial(
            &public_evals[0],
            powers_of_eval_points_for_chunks.zeta,
        );

        ft_eval0 -= evals
            .w
            .iter()
            .zip(index.shift.iter())
            .map(|(w, s)| gamma + (beta * zeta * s) + w.zeta)
            .fold(
                alpha0 * permutation_vanishing_polynomial * evals.z.zeta,
                |x, y| x * y,
            );

        let numerator = ((zeta1m1 * alpha1 * (zeta - index.w()))
            + (zeta1m1 * alpha2 * (zeta - G::ScalarField::one())))
            * (G::ScalarField::one() - evals.z.zeta);

        let denominator = (zeta - index.w()) * (zeta - G::ScalarField::one());
        let denominator = denominator.inverse().expect("negligible probability");

        ft_eval0 += numerator * denominator;

        let constants = Constants {
            alpha,
            beta,
            gamma,
            joint_combiner: joint_combiner.as_ref().map(|j| j.1),
            endo_coefficient: index.endo,
            mds: &G::sponge_params().mds,
            zk_rows,
        };

        ft_eval0 -= PolishToken::evaluate(
            &index.linearization.constant_term,
            index.domain,
            zeta,
            &evals,
            &constants,
        )
        .unwrap();

        ft_eval0
    };

    let combined_inner_product =
        {
            let ft_eval0 = vec![ft_eval0];
            let ft_eval1 = vec![proof.ft_eval1];

            #[allow(clippy::type_complexity)]
            let mut es: Vec<(Vec<Vec<G::ScalarField>>, Option<usize>)> =
                polys.iter().map(|(_, e)| (e.clone(), None)).collect();
            es.push((public_evals.to_vec(), None));
            es.push((vec![ft_eval0, ft_eval1], None));
            for col in
                [
                    Column::Z,
                    Column::Index(GateType::Generic),
                    Column::Index(GateType::Poseidon),
                    Column::Index(GateType::CompleteAdd),
                    Column::Index(GateType::VarBaseMul),
                    Column::Index(GateType::EndoMul),
                    Column::Index(GateType::EndoMulScalar),
                ]
                .into_iter()
                .chain((0..COLUMNS).map(Column::Witness))
                .chain((0..COLUMNS).map(Column::Coefficient))
                .chain((0..PERMUTS - 1).map(Column::Permutation))
                .chain(
                    index
                        .range_check0_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::RangeCheck0)),
                )
                .chain(
                    index
                        .range_check1_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::RangeCheck1)),
                )
                .chain(
                    index
                        .foreign_field_add_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::ForeignFieldAdd)),
                )
                .chain(
                    index
                        .foreign_field_mul_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::ForeignFieldMul)),
                )
                .chain(
                    index
                        .xor_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::Xor16)),
                )
                .chain(
                    index
                        .rot_comm
                        .as_ref()
                        .map(|_| Column::Index(GateType::Rot64)),
                )
                .chain(
                    index
                        .lookup_index
                        .as_ref()
                        .map(|li| {
                            (0..li.lookup_info.max_per_row + 1)
                                .map(Column::LookupSorted)
                                .chain([Column::LookupAggreg, Column::LookupTable].into_iter())
                                .chain(
                                    li.runtime_tables_selector
                                        .as_ref()
                                        .map(|_| [Column::LookupRuntimeTable].into_iter())
                                        .into_iter()
                                        .flatten(),
                                )
                                .chain(
                                    proof
                                        .evals
                                        .runtime_lookup_table_selector
                                        .as_ref()
                                        .map(|_| Column::LookupRuntimeSelector),
                                )
                                .chain(
                                    proof
                                        .evals
                                        .xor_lookup_selector
                                        .as_ref()
                                        .map(|_| Column::LookupKindIndex(LookupPattern::Xor)),
                                )
                                .chain(
                                    proof
                                        .evals
                                        .lookup_gate_lookup_selector
                                        .as_ref()
                                        .map(|_| Column::LookupKindIndex(LookupPattern::Lookup)),
                                )
                                .chain(
                                    proof.evals.range_check_lookup_selector.as_ref().map(|_| {
                                        Column::LookupKindIndex(LookupPattern::RangeCheck)
                                    }),
                                )
                                .chain(proof.evals.foreign_field_mul_lookup_selector.as_ref().map(
                                    |_| Column::LookupKindIndex(LookupPattern::ForeignFieldMul),
                                ))
                        })
                        .into_iter()
                        .flatten(),
                )
            {
                es.push((
                    {
                        let evals = proof
                            .evals
                            .get_column(col)
                            .ok_or(VerifyError::MissingEvaluation(col))?;
                        vec![evals.zeta.clone(), evals.zeta_omega.clone()]
                    },
                    None,
                ))
            }

            combined_inner_product(&evaluation_points, &v, &u, &es, index.srs().max_poly_size())
        };

    let oracles = RandomOracles {
        joint_combiner,
        beta,
        gamma,
        alpha_chal,
        alpha,
        zeta,
        v,
        u,
        zeta_chal,
        v_chal,
        u_chal,
    };

    Ok(OraclesResult {
        fq_sponge,
        digest,
        oracles,
        all_alphas,
        public_evals,
        powers_of_eval_points_for_chunks,
        polys,
        zeta1,
        ft_eval0,
        combined_inner_product,
    })
}
