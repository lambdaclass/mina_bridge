import { Polynomial } from "../polynomial.js"
import { Field, Group, Scalar } from "o1js"
import { PolyComm, bPoly, bPolyCoefficients } from "../poly_commitment/commitment";
import { getLimbs64 } from "../util/bigint";
import { Sponge } from "../verifier/sponge";
import { Verifier, VerifierIndex } from "../verifier/verifier.js";
import { powScalar } from "../util/scalar.js";

/** The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<Array<Scalar>>>
    prev_challenges: RecursionChallenge[]
    commitments: ProverCommitments

    constructor(
        evals: ProofEvaluations<PointEvaluations<Scalar[]>>,
        prev_challenges: RecursionChallenge[],
        commitments: ProverCommitments
    ) {
        this.evals = evals;
        this.prev_challenges = prev_challenges;
        this.commitments = commitments;
    }

    /**
     * Will run the random oracle argument for removing prover-verifier interaction (Fiat-Shamir transform)
     */
    oracles(index: VerifierIndex, public_comm: PolyComm<Group>, public_input?: Scalar[]) {
        let sponge_test = new Sponge();
        const fields = [Field.from(1), Field.from(2)];
        fields.forEach((f) => {
            sponge_test.absorb(f);
        });

        const n = index.domain_size;
        const endo_r = Scalar.from("0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1");
        // FIXME: ^ currently hard-coded, refactor this in the future

        let chunk_size;
        if (index.domain_size < index.max_poly_size) {
            chunk_size = 1;
        } else {
            chunk_size = index.domain_size / index.max_poly_size;
        }

        let zk_rows = index.zk_rows;
        //~ 1. Setup the Fq-Sponge.
        let fq_sponge = new Sponge();

        //~ 2. Absorb the digest of the VerifierIndex.
        fq_sponge.absorb(index.digest());

        //~ 3. Absorb the commitments of the previous challenges with the Fq-sponge.
        this.prev_challenges.forEach(
            (challenge) => fq_sponge.absorbCommitment.bind(fq_sponge)(challenge.comm)
        );

        //~ 4. Absorb the commitment of the public input polynomial with the Fq-Sponge.
        fq_sponge.absorbCommitment(public_comm);

        //~ 5. Absorb the commitments to the registers / witness columns with the Fq-Sponge.
        this.commitments.wComm.forEach(fq_sponge.absorbCommitment.bind(fq_sponge));

        //~ 6. If lookup is used:
        // WARN: omitted lookup-related for now

        //~ 7. Sample $\beta$ with the Fq-Sponge.
        const beta = fq_sponge.challenge();

        //~ 8. Sample $\gamma$ with the Fq-Sponge.
        const gamma = fq_sponge.challenge();

        //~ 9. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        // WARN: omitted lookup-related for now

        //~ 10. Absorb the commitment to the permutation trace with the Fq-Sponge.
        fq_sponge.absorbCommitment(this.commitments.zComm);

        //~ 11. Sample $\alpha'$ with the Fq-Sponge.
        const alpha_chal = new ScalarChallenge(fq_sponge.challenge());

        //~ 12. Derive $\alpha$ from $\alpha'$ using the endomorphism (TODO: details).
        const alpha = alpha_chal.toField(endo_r);

        //~ 13. Enforce that the length of the $t$ commitment is of size `PERMUTS`.
        if (this.commitments.tComm.unshifted.length !== Verifier.PERMUTS) {
            // FIXME: return error "incorrect commitment length of 't'"
        }

        //~ 14. Absorb the commitment to the quotient polynomial $t$ into the argument.
        fq_sponge.absorbCommitment(this.commitments.tComm);

        //~ 15. Sample $\zeta'$ with the Fq-Sponge.
        const zeta_chal = new ScalarChallenge(fq_sponge.challenge());

        //~ 16. Derive $\zeta$ from $\zeta'$ using the endomorphism (TODO: specify).
        const zeta = zeta_chal.toField(endo_r);

        //~ 17. Setup the Fr-Sponge.
        let fr_sponge = new Sponge();
        const digest = fq_sponge.digest();

        //~ 18. Squeeze the Fq-sponge and absorb the result with the Fr-Sponge.
        fr_sponge.absorbScalar(digest);

        //~ 19. Absorb the previous recursion challenges.
        // Note: we absorb in a new sponge here to limit the scope in which we need the
        // more-expensive 'optional sponge'.
        let fr_sponge_aux = new Sponge();
        this.prev_challenges.forEach((prev) => fr_sponge_aux.absorbScalars(prev.chals));
        fr_sponge.absorbScalar(fr_sponge_aux.digest());

        // prepare some often used values

        let zeta1 = powScalar(zeta, n);
        const zetaw = zeta.mul(index.domain_gen);
        const evaluation_points = [zeta, zetaw];
        const powers_of_eval_points_for_chunks: PointEvaluations<Scalar> = {
            zeta: powScalar(zeta, index.max_poly_size),
            zetaOmega: powScalar(zetaw, index.max_poly_size)
        };

        //~ 20. Compute evaluations for the previous recursion challenges.
        const polys = this.prev_challenges.map((chal) => {
            const evals = chal.evals(
                index.max_poly_size,
                evaluation_points,
                [
                    powers_of_eval_points_for_chunks.zeta,
                    powers_of_eval_points_for_chunks.zetaOmega
                ]
            );
            return [chal.comm, evals];
        });

        // retrieve ranges for the powers of alphas
        let all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);

        let public_evals;
        if (this.evals.public_input) {
            public_evals = [this.evals.public_input.zeta, this.evals.public_input.zetaOmega];
        } else if (chunk_size > 1) {
            // FIXME: missing public input eval error
        } else if (public_input) {
            // compute Lagrange base evaluation denominators
            let w = [Scalar.from(1)];
            for (let i = 0; i < public_input.length; i++) {
                w.push(powScalar(index.domain_gen, i));
            }

            let zeta_minus_x = w.map((w_i) => zeta.sub(w_i));

            w.forEach((w_i) => zeta_minus_x.push(zetaw.sub(w_i)))

            zeta_minus_x = zeta_minus_x.map(Scalar.from(1).div);

            //~ 21. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            //  NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
            if (public_input.length === 0) {
                public_evals = [[Scalar.from(0)], [Scalar.from(0)]];
            } else {

            }
        }


        // let public_evals = if let Some(public_evals) = &self.evals.public {
        //     [public_evals.zeta.clone(), public_evals.zeta_omega.clone()]
        // } else if chunk_size > 1 {
        //     return Err(VerifyError::MissingPublicInputEvaluation);
        // } else if let Some(public_input) = public_input {
        //     // compute Lagrange base evaluation denominators
        //     let w: Vec<_> = index.domain.elements().take(public_input.len()).collect();

        //     let mut zeta_minus_x: Vec<_> = w.iter().map(|w| zeta - w).collect();

        //     w.iter()
        //         .take(public_input.len())
        //         .for_each(|w| zeta_minus_x.push(zetaw - w));

        //     ark_ff::fields::batch_inversion::<G::ScalarField>(&mut zeta_minus_x);

        //     //~ 1. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
        //     //~
        //     //~    NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
        //     if public_input.is_empty() {
        //         [vec![G::ScalarField::zero()], vec![G::ScalarField::zero()]]
        //     } else {
        //         [
        //             vec![
        //                 (public_input
        //                     .iter()
        //                     .zip(zeta_minus_x.iter())
        //                     .zip(index.domain.elements())
        //                     .map(|((p, l), w)| -*l * p * w)
        //                     .fold(G::ScalarField::zero(), |x, y| x + y))
        //                     * (zeta1 - G::ScalarField::one())
        //                     * index.domain.size_inv,
        //             ],
        //             vec![
        //                 (public_input
        //                     .iter()
        //                     .zip(zeta_minus_x[public_input.len()..].iter())
        //                     .zip(index.domain.elements())
        //                     .map(|((p, l), w)| -*l * p * w)
        //                     .fold(G::ScalarField::zero(), |x, y| x + y))
        //                     * index.domain.size_inv
        //                     * (zetaw.pow([n]) - G::ScalarField::one()),
        //             ],
        //         ]
        //     }
        // } else {
        //     return Err(VerifyError::MissingPublicInputEvaluation);
        // };

        // //~ 1. Absorb the unique evaluation of ft: $ft(\zeta\omega)$.
        // fr_sponge.absorb(&self.ft_eval1);

        // //~ 1. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
        // //~~ * the public polynomial
        // //~~ * z
        // //~~ * generic selector
        // //~~ * poseidon selector
        // //~~ * the 15 register/witness
        // //~~ * 6 sigmas evaluations (the last one is not evaluated)
        // fr_sponge.absorb_multiple(&public_evals[0]);
        // fr_sponge.absorb_multiple(&public_evals[1]);
        // fr_sponge.absorb_evaluations(&self.evals);

        // //~ 1. Sample $v'$ with the Fr-Sponge.
        // let v_chal = fr_sponge.challenge();

        // //~ 1. Derive $v$ from $v'$ using the endomorphism (TODO: specify).
        // let v = v_chal.to_field(endo_r);

        // //~ 1. Sample $u'$ with the Fr-Sponge.
        // let u_chal = fr_sponge.challenge();

        // //~ 1. Derive $u$ from $u'$ using the endomorphism (TODO: specify).
        // let u = u_chal.to_field(endo_r);

        // //~ 1. Create a list of all polynomials that have an evaluation proof.

        // let evals = self.evals.combine(&powers_of_eval_points_for_chunks);

        // //~ 1. Compute the evaluation of $ft(\zeta)$.
        // let ft_eval0 = {
        //     let permutation_vanishing_polynomial =
        //         index.permutation_vanishing_polynomial_m().evaluate(&zeta);
        //     let zeta1m1 = zeta1 - G::ScalarField::one();

        //     let mut alpha_powers =
        //         all_alphas.get_alphas(ArgumentType::Permutation, permutation::CONSTRAINTS);
        //     let alpha0 = alpha_powers
        //         .next()
        //         .expect("missing power of alpha for permutation");
        //     let alpha1 = alpha_powers
        //         .next()
        //         .expect("missing power of alpha for permutation");
        //     let alpha2 = alpha_powers
        //         .next()
        //         .expect("missing power of alpha for permutation");

        //     let init = (evals.w[PERMUTS - 1].zeta + gamma)
        //         * evals.z.zeta_omega
        //         * alpha0
        //         * permutation_vanishing_polynomial;
        //     let mut ft_eval0 = evals
        //         .w
        //         .iter()
        //         .zip(evals.s.iter())
        //         .map(|(w, s)| (beta * s.zeta) + w.zeta + gamma)
        //         .fold(init, |x, y| x * y);

        //     ft_eval0 -= DensePolynomial::eval_polynomial(
        //         &public_evals[0],
        //         powers_of_eval_points_for_chunks.zeta,
        //     );

        //     ft_eval0 -= evals
        //         .w
        //         .iter()
        //         .zip(index.shift.iter())
        //         .map(|(w, s)| gamma + (beta * zeta * s) + w.zeta)
        //         .fold(
        //             alpha0 * permutation_vanishing_polynomial * evals.z.zeta,
        //             |x, y| x * y,
        //         );

        //     let numerator = ((zeta1m1 * alpha1 * (zeta - index.w()))
        //         + (zeta1m1 * alpha2 * (zeta - G::ScalarField::one())))
        //         * (G::ScalarField::one() - evals.z.zeta);

        //     let denominator = (zeta - index.w()) * (zeta - G::ScalarField::one());
        //     let denominator = denominator.inverse().expect("negligible probability");

        //     ft_eval0 += numerator * denominator;

        //     let constants = Constants {
        //         alpha,
        //         beta,
        //         gamma,
        //         joint_combiner: joint_combiner.as_ref().map(|j| j.1),
        //         endo_coefficient: index.endo,
        //         mds: &G::sponge_params().mds,
        //         zk_rows,
        //     };

        //     ft_eval0 -= PolishToken::evaluate(
        //         &index.linearization.constant_term,
        //         index.domain,
        //         zeta,
        //         &evals,
        //         &constants,
        //     )
        //     .unwrap();

        //     ft_eval0
        // };

        // let combined_inner_product =
        //     {
        //         let ft_eval0 = vec![ft_eval0];
        //         let ft_eval1 = vec![self.ft_eval1];

        //         #[allow(clippy::type_complexity)]
        //         let mut es: Vec<(Vec<Vec<G::ScalarField>>, Option<usize>)> =
        //             polys.iter().map(|(_, e)| (e.clone(), None)).collect();
        //         es.push((public_evals.to_vec(), None));
        //         es.push((vec![ft_eval0, ft_eval1], None));
        //         for col in [
        //             Column::Z,
        //             Column::Index(GateType::Generic),
        //             Column::Index(GateType::Poseidon),
        //             Column::Index(GateType::CompleteAdd),
        //             Column::Index(GateType::VarBaseMul),
        //             Column::Index(GateType::EndoMul),
        //             Column::Index(GateType::EndoMulScalar),
        //         ]
        //         .into_iter()
        //         .chain((0..COLUMNS).map(Column::Witness))
        //         .chain((0..COLUMNS).map(Column::Coefficient))
        //         .chain((0..PERMUTS - 1).map(Column::Permutation))
        //         .chain(
        //             index
        //                 .range_check0_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::RangeCheck0)),
        //         )
        //         .chain(
        //             index
        //                 .range_check1_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::RangeCheck1)),
        //         )
        //         .chain(
        //             index
        //                 .foreign_field_add_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::ForeignFieldAdd)),
        //         )
        //         .chain(
        //             index
        //                 .foreign_field_mul_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::ForeignFieldMul)),
        //         )
        //         .chain(
        //             index
        //                 .xor_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::Xor16)),
        //         )
        //         .chain(
        //             index
        //                 .rot_comm
        //                 .as_ref()
        //                 .map(|_| Column::Index(GateType::Rot64)),
        //         )
        //         .chain(
        //             index
        //                 .lookup_index
        //                 .as_ref()
        //                 .map(|li| {
        //                     (0..li.lookup_info.max_per_row + 1)
        //                         .map(Column::LookupSorted)
        //                         .chain([Column::LookupAggreg, Column::LookupTable].into_iter())
        //                         .chain(
        //                             li.runtime_tables_selector
        //                                 .as_ref()
        //                                 .map(|_| [Column::LookupRuntimeTable].into_iter())
        //                                 .into_iter()
        //                                 .flatten(),
        //                         )
        //                         .chain(
        //                             self.evals
        //                                 .runtime_lookup_table_selector
        //                                 .as_ref()
        //                                 .map(|_| Column::LookupRuntimeSelector),
        //                         )
        //                         .chain(
        //                             self.evals
        //                                 .xor_lookup_selector
        //                                 .as_ref()
        //                                 .map(|_| Column::LookupKindIndex(LookupPattern::Xor)),
        //                         )
        //                         .chain(
        //                             self.evals
        //                                 .lookup_gate_lookup_selector
        //                                 .as_ref()
        //                                 .map(|_| Column::LookupKindIndex(LookupPattern::Lookup)),
        //                         )
        //                         .chain(
        //                             self.evals.range_check_lookup_selector.as_ref().map(|_| {
        //                                 Column::LookupKindIndex(LookupPattern::RangeCheck)
        //                             }),
        //                         )
        //                         .chain(self.evals.foreign_field_mul_lookup_selector.as_ref().map(
        //                             |_| Column::LookupKindIndex(LookupPattern::ForeignFieldMul),
        //                         ))
        //                 })
        //                 .into_iter()
        //                 .flatten(),
        //         ) {
        //             es.push((
        //                 {
        //                     let evals = self
        //                         .evals
        //                         .get_column(col)
        //                         .ok_or(VerifyError::MissingEvaluation(col))?;
        //                     vec![evals.zeta.clone(), evals.zeta_omega.clone()]
        //                 },
        //                 None,
        //             ))
        //         }

        //         combined_inner_product(&evaluation_points, &v, &u, &es, index.srs().g.len())
        //     };

        // let oracles = RandomOracles {
        //     joint_combiner,
        //     beta,
        //     gamma,
        //     alpha_chal,
        //     alpha,
        //     zeta,
        //     v,
        //     u,
        //     zeta_chal,
        //     v_chal,
        //     u_chal,
        // };

        // Ok(OraclesResult {
        //     fq_sponge,
        //     digest,
        //     oracles,
        //     all_alphas,
        //     public_evals,
        //     powers_of_eval_points_for_chunks,
        //     polys,
        //     zeta1,
        //     ft_eval0,
        //     combined_inner_product,
        // })
    }
}

export class Context {
    /* The [VerifierIndex] associated to the proof */
    verifier_index: VerifierIndex

    /* The proof to verify */
    proof: ProverProof

    /* The public input used in the creation of the proof */
    public_input: Scalar[]
};

/**
 * Polynomial evaluations contained in a `ProverProof`.
 * **Chunked evaluations** `Field` is instantiated with vectors with a length that equals the length of the chunk
 * **Non chunked evaluations** `Field` is instantiated with a field, so they are single-sized#[serde_as]
 */
export class ProofEvaluations<Evals> {
    /* public input polynomials */
    public_input?: Evals
    /* witness polynomials */
    w: Array<Evals> // of size 15, total num of registers (columns)
    /* permutation polynomial */
    z: Evals
    /*
     * permutation polynomials
     * (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
     */
    s: Array<Evals> // of size 7 - 1, total num of wirable registers minus one
    /* coefficient polynomials */
    coefficients: Array<Evals> // of size 15, total num of registers (columns)
    /* lookup-related evaluations */
    lookup?: LookupEvaluations<Evals>
    /* evaluation of the generic selector polynomial */
    genericSelector: Evals
    /* evaluation of the poseidon selector polynomial */
    poseidonSelector: Evals

    constructor(
        w: Array<Evals>,
        z: Evals, s: Array<Evals>,
        coefficients: Array<Evals>,
        lookup: LookupEvaluations<Evals>,
        genericSelector: Evals,
        poseidonSelector: Evals,
        public_input?: Evals,
    ) {
        this.w = w;
        this.z = z;
        this.s = s;
        this.coefficients = coefficients;
        this.lookup = lookup;
        this.genericSelector = genericSelector;
        this.poseidonSelector = poseidonSelector;
        this.public_input = public_input;
        return this;
    }

    // TODO: implement this!!!!
    /*
    Returns a new PointEvaluations struct with the combined evaluations.
    */
    combine_point_evaluations(): PointEvaluations<Evals> {
        let zeta: Evals = Scalar.from(0) as Evals;
        let zetaOmega: Evals = Scalar.from(0) as Evals;

        let ret = new PointEvaluations(zeta, zetaOmega);
        return ret;
    }
    /*
    pub fn combine(&self, pt: &PointEvaluations<F>) -> ProofEvaluations<PointEvaluations<F>> {
        self.map_ref(&|evals| PointEvaluations {
            zeta: DensePolynomial::eval_polynomial(&evals.zeta, pt.zeta),
            zeta_omega: DensePolynomial::eval_polynomial(&evals.zeta_omega, pt.zeta_omega),
        })
    }    
    */

    evaluate_coefficients(point: Scalar): Scalar {
        let zero = Scalar.from(0);

        let coeffs = this.coefficients.map((value) => value as Scalar);
        let p = new Polynomial(coeffs);
        if (this.coefficients.length == 0) {
            return zero;
        }
        if (point == zero) {
            return this.coefficients[0] as Scalar;
        }
        return p.evaluate(point);
    }
}

/**
 * Evaluations of lookup polynomials.
 */
export class LookupEvaluations<Evals> {
    /* sorted lookup table polynomial */
    sorted: Array<Evals>
    /* lookup aggregation polynomial */
    aggreg: Evals
    /* lookup table polynomial */
    table: Evals
    /* runtime table polynomial*/
    runtime?: Evals

    constructor() {
        this.sorted = [];
        return this;
    }
}

/**
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: Evals

    constructor(zeta: Evals, zetaOmega: Evals) {
        this.zeta = zeta;
        this.zetaOmega = zetaOmega;
    }
}

/**
 * Stores the challenges inside a `ProverProof`
 */
export class RecursionChallenge {
    chals: Scalar[]
    comm: PolyComm<Group>

    evals(
        max_poly_size: number,
        evaluation_points: Scalar[],
        powers_of_eval_points_for_chunks: Scalar[]
    ): Scalar[][] {
        const chals = this.chals;
        // Comment copied from Kimchi code:
        //
        // No need to check the correctness of poly explicitly. Its correctness is assured by the
        // checking of the inner product argument.
        const b_len = 1 << chals.length;
        let b: Scalar[] | undefined = undefined;

        return [0, 1, 2].map((i) => {
            const full = bPoly(chals, evaluation_points[i])
            if (max_poly_size === b_len) {
                return [full];
            }

            let betacc = Scalar.from(1);
            let diffs: Scalar[] = [];
            for (let j = max_poly_size; j < b_len; j++) {
                let b_j;
                if (b) {
                    b_j = b[j];
                } else {
                    const t = bPolyCoefficients(chals);
                    const res = t[j];
                    b = t;
                    b_j = res;
                }

                const ret = betacc.mul(b_j);
                betacc = betacc.mul(evaluation_points[i]);
                diffs.push(ret);
            }

            const diff = diffs.reduce((x, y) => x.add(y), Scalar.from(0));
            return [full.sub(diff.mul(powers_of_eval_points_for_chunks[i])), diff];
        });
    }
}

export class ProverCommitments {
    /* Commitments to the witness (execution trace) */
    wComm: PolyComm<Group>[]
    /* Commitment to the permutation */
    zComm: PolyComm<Group>
    /* Commitment to the quotient polynomial */
    tComm: PolyComm<Group>
    // TODO: lookup commitment
}

function getBit(limbs_lsb: bigint[], i: number): bigint {
    const limb = Math.floor(i / 64);
    const j = BigInt(i % 64);
    return (limbs_lsb[limb] >> j) & 1n;
    // FIXME: if it's negative, then >> will fill with ones
}

export class ScalarChallenge {
    chal: Scalar

    constructor(chal: Scalar) {
        this.chal = chal;
    }

    toFieldWithLength(length_in_bits: number, endo_coeff: Scalar): Scalar {
        const rep = this.chal.toBigInt();
        const rep_64_limbs = getLimbs64(rep);

        let a = Scalar.from(2);
        let b = Scalar.from(2);

        const one = Scalar.from(1);
        const negone = one.neg();
        for (let i = Math.floor(length_in_bits / 2) - 1; i >= 0; i--) {
            a = a.add(a);
            b = b.add(b);

            const r_2i = getBit(rep_64_limbs, 2 * i);
            const s = r_2i === 0n ? negone : one;

            if (getBit(rep_64_limbs, 2 * i + 1) === 0n) {
                b = b.add(s);
            } else {
                a = a.add(s);
            }
        }

        return a.mul(endo_coeff).add(b);
    }

    toField(endo_coeff: Scalar): Scalar {
        const length_in_bits = 64 * Sponge.CHALLENGE_LENGTH_IN_LIMBS;
        return this.toFieldWithLength(length_in_bits, endo_coeff);
    }
}
