import { Field, Group, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment";
import { Sponge } from "../verifier/sponge";
import { Verifier, VerifierIndex } from "../verifier/verifier.js";

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
    oracles(index: VerifierIndex, public_comm: PolyComm<Group>, public_input: Scalar[]) {
        let sponge_test = new Sponge();
        const fields = [Field.from(1), Field.from(2)];
        fields.forEach((f) => {
            console.log(sponge_test.lastSqueezed);
            sponge_test.absorb(f);
        });
        console.log("TEST SPONGE");

        const n = index.domain_size;
        const endo_r = Scalar.from("0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1");
        // FIXME: ^ currently hard-coded, refactor

        //~ 1. Setup the Fq-Sponge.
        let fq_sponge = new Sponge();

        //~ 2. Absorb the digest of the VerifierIndex.
        fq_sponge.absorb(index.digest());

        //~ 3. Absorb the commitments of the previous challenges with the Fq-sponge.
        this.prev_challenges.forEach(
            (challenge) => fq_sponge.absorbCommitment(challenge.comm)
        );

        //~ 4. Absorb the commitment of the public input polynomial with the Fq-Sponge.
        fq_sponge.absorbCommitment(public_comm);

        //~ 5. Absorb the commitments to the registers / witness columns with the Fq-Sponge.
        this.commitments.wComm.forEach(fq_sponge.absorbCommitment);

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
        fr_sponge.absorbScalar(fr_sponge.digest());

        //   // prepare some often used values
        //   let zeta1 = zeta.pow([n]);
        //   let zetaw = zeta * index.domain.group_gen;
        //   let evaluation_points = [zeta, zetaw];
        //   let powers_of_eval_points_for_chunks = PointEvaluations {
        //       zeta: zeta.pow([index.max_poly_size as u64]),
        //       zeta_omega: zetaw.pow([index.max_poly_size as u64]),
        //   };

        //   //~ 1. Compute evaluations for the previous recursion challenges.
        //   let polys: Vec<(PolyComm<G>, _)> = self
        //       .prev_challenges
        //       .iter()
        //       .map(|challenge| {
        //           let evals = challenge.evals(
        //               index.max_poly_size,
        //               &evaluation_points,
        //               &[
        //                   powers_of_eval_points_for_chunks.zeta,
        //                   powers_of_eval_points_for_chunks.zeta_omega,
        //               ],
        //           );
        //           let RecursionChallenge { chals: _, comm } = challenge;
        //           (comm.clone(), evals)
        //       })
        //       .collect();

        //   // retrieve ranges for the powers of alphas
        //   let mut all_alphas = index.powers_of_alpha.clone();
        //   all_alphas.instantiate(alpha);

        //   // compute Lagrange base evaluation denominators
        //   let w: Vec<_> = index.domain.elements().take(public_input.len()).collect();

        //   let mut zeta_minus_x: Vec<_> = w.iter().map(|w| zeta - w).collect();

        //   w.iter()
        //       .take(public_input.len())
        //       .for_each(|w| zeta_minus_x.push(zetaw - w));

        //   ark_ff::fields::batch_inversion::<G::ScalarField>(&mut zeta_minus_x);

        //   //~ 1. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
        //   //~
        //   //~    NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
        //   let public_evals = if public_input.is_empty() {
        //       [vec![G::ScalarField::zero()], vec![G::ScalarField::zero()]]
        //   } else {
        //       [
        //           vec![
        //               (public_input
        //                   .iter()
        //                   .zip(zeta_minus_x.iter())
        //                   .zip(index.domain.elements())
        //                   .map(|((p, l), w)| -*l * p * w)
        //                   .fold(G::ScalarField::zero(), |x, y| x + y))
        //                   * (zeta1 - G::ScalarField::one())
        //                   * index.domain.size_inv,
        //           ],
        //           vec![
        //               (public_input
        //                   .iter()
        //                   .zip(zeta_minus_x[public_input.len()..].iter())
        //                   .zip(index.domain.elements())
        //                   .map(|((p, l), w)| -*l * p * w)
        //                   .fold(G::ScalarField::zero(), |x, y| x + y))
        //                   * index.domain.size_inv
        //                   * (zetaw.pow([n]) - G::ScalarField::one()),
        //           ],
        //       ]
        //   };

        //   //~ 1. Absorb the unique evaluation of ft: $ft(\zeta\omega)$.
        //   fr_sponge.absorb(&self.ft_eval1);

        //   //~ 1. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
        //   //~~ * the public polynomial
        //   //~~ * z
        //   //~~ * generic selector
        //   //~~ * poseidon selector
        //   //~~ * the 15 register/witness
        //   //~~ * 6 sigmas evaluations (the last one is not evaluated)
        //   fr_sponge.absorb_multiple(&public_evals[0]);
        //   fr_sponge.absorb_multiple(&public_evals[1]);
        //   fr_sponge.absorb_evaluations(&self.evals);

        //   //~ 1. Sample $v'$ with the Fr-Sponge.
        //   let v_chal = fr_sponge.challenge();

        //   //~ 1. Derive $v$ from $v'$ using the endomorphism (TODO: specify).
        //   let v = v_chal.to_field(endo_r);

        //   //~ 1. Sample $u'$ with the Fr-Sponge.
        //   let u_chal = fr_sponge.challenge();

        //   //~ 1. Derive $u$ from $u'$ using the endomorphism (TODO: specify).
        //   let u = u_chal.to_field(endo_r);

        //   //~ 1. Create a list of all polynomials that have an evaluation proof.

        //   let evals = self.evals.combine(&powers_of_eval_points_for_chunks);

        //   //~ 1. Compute the evaluation of $ft(\zeta)$.
        //   let ft_eval0 = {
        //       let zkp = index.zkpm().evaluate(&zeta);
        //       let zeta1m1 = zeta1 - G::ScalarField::one();

        //       let mut alpha_powers =
        //           all_alphas.get_alphas(ArgumentType::Permutation, permutation::CONSTRAINTS);
        //       let alpha0 = alpha_powers
        //           .next()
        //           .expect("missing power of alpha for permutation");
        //       let alpha1 = alpha_powers
        //           .next()
        //           .expect("missing power of alpha for permutation");
        //       let alpha2 = alpha_powers
        //           .next()
        //           .expect("missing power of alpha for permutation");

        //       let init = (evals.w[PERMUTS - 1].zeta + gamma) * evals.z.zeta_omega * alpha0 * zkp;
        //       let mut ft_eval0 = evals
        //           .w
        //           .iter()
        //           .zip(evals.s.iter())
        //           .map(|(w, s)| (beta * s.zeta) + w.zeta + gamma)
        //           .fold(init, |x, y| x * y);

        //       ft_eval0 -= if public_evals[0].is_empty() {
        //           G::ScalarField::zero()
        //       } else {
        //           public_evals[0][0]
        //       };

        //       ft_eval0 -= evals
        //           .w
        //           .iter()
        //           .zip(index.shift.iter())
        //           .map(|(w, s)| gamma + (beta * zeta * s) + w.zeta)
        //           .fold(alpha0 * zkp * evals.z.zeta, |x, y| x * y);

        //       let numerator = ((zeta1m1 * alpha1 * (zeta - index.w()))
        //           + (zeta1m1 * alpha2 * (zeta - G::ScalarField::one())))
        //           * (G::ScalarField::one() - evals.z.zeta);

        //       let denominator = (zeta - index.w()) * (zeta - G::ScalarField::one());
        //       let denominator = denominator.inverse().expect("negligible probability");

        //       ft_eval0 += numerator * denominator;

        //       let constants = Constants {
        //           alpha,
        //           beta,
        //           gamma,
        //           joint_combiner: joint_combiner.as_ref().map(|j| j.1),
        //           endo_coefficient: index.endo,
        //           mds: &G::sponge_params().mds,
        //       };

        //       ft_eval0 -= PolishToken::evaluate(
        //           &index.linearization.constant_term,
        //           index.domain,
        //           zeta,
        //           &evals,
        //           &constants,
        //       )
        //       .unwrap();

        //       ft_eval0
        //   };

        //   let combined_inner_product = {
        //       let ft_eval0 = vec![ft_eval0];
        //       let ft_eval1 = vec![self.ft_eval1];

        //       #[allow(clippy::type_complexity)]
        //       let mut es: Vec<(Vec<Vec<G::ScalarField>>, Option<usize>)> =
        //           polys.iter().map(|(_, e)| (e.clone(), None)).collect();
        //       es.push((public_evals.to_vec(), None));
        //       es.push((vec![ft_eval0, ft_eval1], None));
        //       for col in [
        //           Column::Z,
        //           Column::Index(GateType::Generic),
        //           Column::Index(GateType::Poseidon),
        //       ]
        //       .into_iter()
        //       .chain((0..COLUMNS).map(Column::Witness))
        //       .chain((0..COLUMNS).map(Column::Coefficient))
        //       .chain((0..PERMUTS - 1).map(Column::Permutation))
        //       .chain(
        //           index
        //               .lookup_index
        //               .as_ref()
        //               .map(|li| {
        //                   (0..li.lookup_info.max_per_row + 1)
        //                       .map(Column::LookupSorted)
        //                       .chain([Column::LookupAggreg, Column::LookupTable].into_iter())
        //                       .chain(
        //                           li.runtime_tables_selector
        //                               .as_ref()
        //                               .map(|_| [Column::LookupRuntimeTable].into_iter())
        //                               .into_iter()
        //                               .flatten(),
        //                       )
        //               })
        //               .into_iter()
        //               .flatten(),
        //       ) {
        //           es.push((
        //               {
        //                   let evals = self
        //                       .evals
        //                       .get_column(col)
        //                       .ok_or(VerifyError::MissingEvaluation(col))?;
        //                   vec![evals.zeta.clone(), evals.zeta_omega.clone()]
        //               },
        //               None,
        //           ))
        //       }

        //       combined_inner_product(&evaluation_points, &v, &u, &es, index.srs().g.len())
        //   };

        //   let oracles = RandomOracles {
        //       joint_combiner,
        //       beta,
        //       gamma,
        //       alpha_chal,
        //       alpha,
        //       zeta,
        //       v,
        //       u,
        //       zeta_chal,
        //       v_chal,
        //       u_chal,
        //   };

        //   Ok(OraclesResult {
        //       fq_sponge,
        //       digest,
        //       oracles,
        //       all_alphas,
        //       public_evals,
        //       powers_of_eval_points_for_chunks,
        //       polys,
        //       zeta1,
        //       ft_eval0,
        //       combined_inner_product,
        //   })
    }//
}

/**
 * Polynomial evaluations contained in a `ProverProof`.
 * **Chunked evaluations** `Field` is instantiated with vectors with a length that equals the length of the chunk
 * **Non chunked evaluations** `Field` is instantiated with a field, so they are single-sized#[serde_as]
 */
export class ProofEvaluations<Evals> {
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
}

/**
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: Evals
}

/**
 * Stores the challenges inside a `ProverProof`
 */
export class RecursionChallenge {
    chals: Scalar[]
    comm: PolyComm<Group>
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

function getBit(limbs_lsb: bigint[], i: number): number {
    const limb = i / 64;
    const j = BigInt(i % 64);
    return Number((limbs_lsb[limb] >> j) & 1n);
}

export class ScalarChallenge {
    chal: Scalar

    constructor(chal: Scalar) {
        this.chal = chal;
    }

    toFieldWithLength(length_in_bits: number, endo_coeff: Scalar): Scalar {
        const rep = this.chal.toBigInt();

        let a = Scalar.from(2);
        let b = Scalar.from(2);

        const one = Scalar.from(1);
        const negone = one.neg();
        for (let i = length_in_bits / 2 + 1; i >= 0; i--) {
            a = a.add(a);
            b = b.add(b);

            const r_2i = getBit([rep], 2*i);
            const s = r_2i === 0 ? negone : one;

            if (getBit([rep], 2*i + 1) === 0) {
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
