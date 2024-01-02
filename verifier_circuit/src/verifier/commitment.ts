/*
    /// This function verifies batch of batched polynomial commitment opening proofs
    ///     batch: batch of batched polynomial commitment opening proofs
    ///          vector of evaluation points
    ///          polynomial scaling factor for this batched openinig proof
    ///          eval scaling factor for this batched openinig proof
    ///          batch/vector of polycommitments (opened in this batch), evaluation vectors and, optionally, max degrees
    ///          opening proof for this batched opening
    ///     oracle_params: parameters for the random oracle argument
    ///     randomness source context
    ///     RETURN: verification status
    pub fn verify<EFqSponge, RNG>(
        &self,
        group_map: &G::Map,
        batch: &mut [BatchEvaluationProof<G, EFqSponge, OpeningProof<G>>],
        rng: &mut RNG,
    ) -> bool
    where
        EFqSponge: FqSponge<G::BaseField, G, G::ScalarField>,
        RNG: RngCore + CryptoRng,
        G::BaseField: PrimeField,
    {
        // Verifier checks for all i,
        // c_i Q_i + delta_i = z1_i (G_i + b_i U_i) + z2_i H
        //
        // if we sample evalscale at random, it suffices to check
        //
        // 0 == sum_i evalscale^i (c_i Q_i + delta_i - ( z1_i (G_i + b_i U_i) + z2_i H ))
        //
        // and because each G_i is a multiexp on the same array self.g, we
        // can batch the multiexp across proofs.
        //
        // So for each proof in the batch, we add onto our big multiexp the following terms
        // evalscale^i c_i Q_i
        // evalscale^i delta_i
        // - (evalscale^i z1_i) G_i
        // - (evalscale^i z2_i) H
        // - (evalscale^i z1_i b_i) U_i

        // We also check that the sg component of the proof is equal to the polynomial commitment
        // to the "s" array

        let nonzero_length = self.g.len();

        let max_rounds = math::ceil_log2(nonzero_length);

        let padded_length = 1 << max_rounds;

        let (_, endo_r) = endos::<G>();

        // TODO: This will need adjusting
        let padding = padded_length - nonzero_length;
        let mut points = vec![self.h];
        points.extend(self.g.clone());
        points.extend(vec![G::zero(); padding]);

        let mut scalars = vec![G::ScalarField::zero(); padded_length + 1];
        assert_eq!(scalars.len(), points.len());

        // sample randomiser to scale the proofs with
        let rand_base = G::ScalarField::rand(rng);
        let sg_rand_base = G::ScalarField::rand(rng);

        let mut rand_base_i = G::ScalarField::one();
        let mut sg_rand_base_i = G::ScalarField::one();

        for BatchEvaluationProof {
            sponge,
            evaluation_points,
            polyscale,
            evalscale,
            evaluations,
            opening,
            combined_inner_product,
        } in batch.iter_mut()
        {
            sponge.absorb_fr(&[shift_scalar::<G>(*combined_inner_product)]);

            let t = sponge.challenge_fq();
            let u: G = to_group(group_map, t);

            let Challenges { chal, chal_inv } = opening.challenges::<EFqSponge>(&endo_r, sponge);

            sponge.absorb_g(&[opening.delta]);
            let c = ScalarChallenge(sponge.challenge()).to_field(&endo_r);

            // < s, sum_i evalscale^i pows(evaluation_point[i]) >
            // ==
            // sum_i evalscale^i < s, pows(evaluation_point[i]) >
            let b0 = {
                let mut scale = G::ScalarField::one();
                let mut res = G::ScalarField::zero();
                for &e in evaluation_points.iter() {
                    let term = b_poly(&chal, e);
                    res += &(scale * term);
                    scale *= *evalscale;
                }
                res
            };

            let s = b_poly_coefficients(&chal);

            let neg_rand_base_i = -rand_base_i;

            // TERM
            // - rand_base_i z1 G
            //
            // we also add -sg_rand_base_i * G to check correctness of sg.
            points.push(opening.sg);
            scalars.push(neg_rand_base_i * opening.z1 - sg_rand_base_i);

            // Here we add
            // sg_rand_base_i * ( < s, self.g > )
            // =
            // < sg_rand_base_i s, self.g >
            //
            // to check correctness of the sg component.
            {
                let terms: Vec<_> = s.par_iter().map(|s| sg_rand_base_i * s).collect();

                for (i, term) in terms.iter().enumerate() {
                    scalars[i + 1] += term;
                }
            }

            // TERM
            // - rand_base_i * z2 * H
            scalars[0] -= &(rand_base_i * opening.z2);

            // TERM
            // -rand_base_i * (z1 * b0 * U)
            scalars.push(neg_rand_base_i * (opening.z1 * b0));
            points.push(u);

            // TERM
            // rand_base_i c_i Q_i
            // = rand_base_i c_i
            //   (sum_j (chal_invs[j] L_j + chals[j] R_j) + P_prime)
            // where P_prime = combined commitment + combined_inner_product * U
            let rand_base_i_c_i = c * rand_base_i;
            for ((l, r), (u_inv, u)) in opening.lr.iter().zip(chal_inv.iter().zip(chal.iter())) {
                points.push(*l);
                scalars.push(rand_base_i_c_i * u_inv);

                points.push(*r);
                scalars.push(rand_base_i_c_i * u);
            }

            // TERM
            // sum_j evalscale^j (sum_i polyscale^i f_i) (elm_j)
            // == sum_j sum_i evalscale^j polyscale^i f_i(elm_j)
            // == sum_i polyscale^i sum_j evalscale^j f_i(elm_j)
            combine_commitments(
                evaluations,
                &mut scalars,
                &mut points,
                *polyscale,
                rand_base_i_c_i,
            );

            scalars.push(rand_base_i_c_i * *combined_inner_product);
            points.push(u);

            scalars.push(rand_base_i);
            points.push(opening.delta);

            rand_base_i *= &rand_base;
            sg_rand_base_i *= &sg_rand_base;
        }

        // verify the equation
        let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
        VariableBaseMSM::multi_scalar_mul(&points, &scalars) == G::Projective::zero()
    }
*/
