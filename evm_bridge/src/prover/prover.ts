import { Group, Poseidon, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment";
import { Sponge } from "../verifier/sponge";
import { VerifierIndex } from "../verifier/Verifier";

/* The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<Array<Scalar>>>
    prev_challenges: RecursionChallenge[]

    /*
     * Will run the random oracle argument for removing prover-verifier interaction (Fiat-Shamir transform)
     */
    oracle(index: VerifierIndex, public_comm: PolyComm<Group>, public_input: Scalar[]) {
        const n = index.domain_size;

        //~ 1. Setup the Fq-Sponge.
        let fq_sponge = new Sponge;

        //~ 2. Absorb the digest of the VerifierIndex.
        fq_sponge.absorb(index.digest());

        //~ 3. Absorb the commitments of the previous challenges with the Fq-sponge.
        this.prev_challenges.forEach(
            (challenge) => fq_sponge.absorbCommitment(challenge.comm)
        );

        //~ 4. Absorb the commitment of the public input polynomial with the Fq-Sponge.
        fq_sponge.absorbCommitment(public_comm);

        //   //~ 1. Absorb the commitment of the public input polynomial with the Fq-Sponge.
        //   absorb_commitment(&mut fq_sponge, public_comm);

        //   //~ 1. Absorb the commitments to the registers / witness columns with the Fq-Sponge.
        //   self.commitments
        //       .w_comm
        //       .iter()
        //       .for_each(|c| absorb_commitment(&mut fq_sponge, c));

        //   //~ 1. If lookup is used:
        //   WARN: omitted lookup-related for now

        //   //~ 1. Sample $\beta$ with the Fq-Sponge.
        //   let beta = fq_sponge.challenge();

        //   //~ 1. Sample $\gamma$ with the Fq-Sponge.
        //   let gamma = fq_sponge.challenge();

        //   //~ 1. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        //   self.commitments.lookup.iter().for_each(|l| {
        //       absorb_commitment(&mut fq_sponge, &l.aggreg);
        //   });

        //   //~ 1. Absorb the commitment to the permutation trace with the Fq-Sponge.
        //   absorb_commitment(&mut fq_sponge, &self.commitments.z_comm);

        //   //~ 1. Sample $\alpha'$ with the Fq-Sponge.
        //   let alpha_chal = ScalarChallenge(fq_sponge.challenge());

        //   //~ 1. Derive $\alpha$ from $\alpha'$ using the endomorphism (TODO: details).
        //   let alpha = alpha_chal.to_field(endo_r);

        //   //~ 1. Enforce that the length of the $t$ commitment is of size `PERMUTS`.
        //   if self.commitments.t_comm.unshifted.len() != PERMUTS {
        //       return Err(VerifyError::IncorrectCommitmentLength("t"));
        //   }

        //   //~ 1. Absorb the commitment to the quotient polynomial $t$ into the argument.
        //   absorb_commitment(&mut fq_sponge, &self.commitments.t_comm);

        //   //~ 1. Sample $\zeta'$ with the Fq-Sponge.
        //   let zeta_chal = ScalarChallenge(fq_sponge.challenge());

        //   //~ 1. Derive $\zeta$ from $\zeta'$ using the endomorphism (TODO: specify).
        //   let zeta = zeta_chal.to_field(endo_r);

        //   //~ 1. Setup the Fr-Sponge.
        //   let digest = fq_sponge.clone().digest();
        //   let mut fr_sponge = EFrSponge::new(G::sponge_params());

        //   //~ 1. Squeeze the Fq-sponge and absorb the result with the Fr-Sponge.
        //   fr_sponge.absorb(&digest);

        //   //~ 1. Absorb the previous recursion challenges.
        //   let prev_challenge_digest = {
        //       // Note: we absorb in a new sponge here to limit the scope in which we need the
        //       // more-expensive 'optional sponge'.
        //       let mut fr_sponge = EFrSponge::new(G::sponge_params());
        //       for RecursionChallenge { chals, .. } in &self.prev_challenges {
        //           fr_sponge.absorb_multiple(chals);
        //       }
        //       fr_sponge.digest()
        //   };
        //   fr_sponge.absorb(&prev_challenge_digest);

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

/*
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

/*
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

/*
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: Evals
}

/*
 * Stores the challenges inside a `ProverProof`
 */
export class RecursionChallenge {
    chals: Scalar[]
    comm: PolyComm<Group>
}
