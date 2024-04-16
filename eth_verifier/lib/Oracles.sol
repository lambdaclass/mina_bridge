// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";
import "./VerifierIndex.sol";
import "./Evaluations.sol";
import "./Alphas.sol";
import "./sponge/Sponge.sol";
import "./Commitment.sol";
import "./Proof.sol";
import "./Polynomial.sol";
import "./Constants.sol";

library Oracles {
    using {to_field_with_length, to_field} for ScalarChallenge;
    using {Scalar.neg, Scalar.add, Scalar.sub, Scalar.mul, Scalar.inv, Scalar.double, Scalar.pow} for Scalar.FE;
    using {instantiate, get_alphas} for Alphas;
    using {it_next} for AlphasIterator;
    using {
        KeccakSponge.reinit,
        KeccakSponge.absorb_base,
        KeccakSponge.absorb_scalar,
        KeccakSponge.absorb_scalar_multiple,
        KeccakSponge.absorb_commitment,
        KeccakSponge.absorb_g_single,
        KeccakSponge.absorb_evaluations,
        KeccakSponge.challenge_base,
        KeccakSponge.challenge_scalar,
        KeccakSponge.digest_base,
        KeccakSponge.digest_scalar
    } for Sponge;
    using {get_column_eval} for ProofEvaluations;

    uint64 internal constant CHALLENGE_LENGTH_IN_LIMBS = 2;

    error IncorrectCommitmentLength(string name, uint256 required_len, uint256 actual_len);
    error MissingPublicInputEvaluation();

    // This takes Kimchi's `oracles()` as reference.
    function fiat_shamir(
        ProverProof memory proof,
        VerifierIndex storage index,
        BN254.G1Point memory public_comm,
        Scalar.FE[] memory public_input,
        bool is_public_input_set,
        Sponge storage base_sponge,
        Sponge storage scalar_sponge
    ) public returns (Result memory) {
        uint256 chunk_size = index.domain_size < index.max_poly_size ? 1 : index.domain_size / index.max_poly_size;

        (Base.FE _endo_q, Scalar.FE endo_r) = BN254.endo_coeffs_g1();

        // 1. Setup the Fq-Sponge.
        base_sponge.reinit();

        // 2. Absorb the digest of the VerifierIndex.
        Base.FE verifier_index_digest = verifier_digest(index);
        console.log("verifier index digest:");
        console.logBytes(abi.encode(verifier_index_digest));
        base_sponge.absorb_base(verifier_index_digest);

        // TODO: 3. Absorb the commitment to the previous challenges.
        // WARN: is this necessary?
        // INFO: For our current o1js proof, this isn't necessary.

        // 4. Absorb the commitment to the public inputs.
        base_sponge.absorb_g_single(public_comm);

        // INFO: up until this point, all previous values only depend on the verifier index which is fixed for a given
        // constraint system.

        // 5. Absorb the commitments to the registers / witness columns
        for (uint256 i = 0; i < proof.commitments.w_comm.length; i++) {
            base_sponge.absorb_g_single(proof.commitments.w_comm[i]);
        }

        // TODO: 6. If lookup is used, absorb runtime commitment
        // INFO: this isn't needed for our current test proof

        // TODO: 7. Calculate joint_combiner
        // INFO: for our test proof this will be zero.
        ScalarChallenge memory joint_combiner = ScalarChallenge(Scalar.zero());
        Scalar.FE joint_combiner_field = joint_combiner.to_field(endo_r);

        // 8. If lookup is used, absorb commitments to the sorted polys:
        for (uint256 i = 0; i < proof.commitments.lookup_sorted.length; i++) {
            base_sponge.absorb_g_single(proof.commitments.lookup_sorted[i]);
        }

        // 9. Sample beta from the sponge
        Scalar.FE beta = base_sponge.challenge_scalar();
        // 10. Sample gamma from the sponge
        Scalar.FE gamma = base_sponge.challenge_scalar();

        // 11. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        base_sponge.absorb_g_single(proof.commitments.lookup_aggreg);

        // 12. Absorb the commitment to the permutation trace with the Fq-Sponge.
        base_sponge.absorb_g_single(proof.commitments.z_comm);

        // 13. Sample alpha prime
        ScalarChallenge memory alpha_chal = ScalarChallenge(base_sponge.challenge_scalar());

        // 14. Derive alpha using the endomorphism
        Scalar.FE alpha = alpha_chal.to_field(endo_r);

        // 15. Enforce that the length of the $t$ commitment is of size 7.
        // INFO: We are assuming the prover is configured accordingly so this is always the case

        // 16. Absorb commitment to the quotient polynomial $t$.
        for (uint256 i = 0; i < proof.commitments.t_comm.length; i++) {
            base_sponge.absorb_g_single(proof.commitments.t_comm[i]);
        }

        // 17. Sample zeta prime
        ScalarChallenge memory zeta_chal = ScalarChallenge(base_sponge.challenge_scalar());
        // 18. Derive zeta using the endomorphism
        Scalar.FE zeta = zeta_chal.to_field(endo_r);

        // 19. Setup a scalar sponge
        scalar_sponge.reinit();

        // 20. Absorb the digest of the previous sponge
        Scalar.FE digest = base_sponge.digest_scalar();
        scalar_sponge.absorb_scalar(digest);

        // TODO: 21. Absorb the previous recursion challenges
        // INFO: our proofs won't have recursion for now, so we only need
        // to absorb the digest of an empty sponge. This will be hardcoded:
        scalar_sponge.absorb_scalar(Scalar.from(0x00C5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A4));

        // often used values
        Scalar.FE zeta1 = zeta.pow(index.domain_size);
        Scalar.FE zetaw = zeta.mul(index.domain_gen);
        Scalar.FE[] memory evaluation_points = new Scalar.FE[](2);
        evaluation_points[0] = zeta;
        evaluation_points[1] = zetaw;
        PointEvaluations memory powers_of_eval_points_for_chunks =
            PointEvaluations(zeta.pow(index.max_poly_size), zetaw.pow(index.max_poly_size));

        // TODO: 22. Compute evaluations for the previous recursion challenges
        // INFO: this isn't necessary for our current test proof

        // retrieve ranges for the powers of alphas
        Alphas storage all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);
        // WARN: all_alphas should be a clone of index.powers_of_alpha, not a reference.
        // in our case we can only have it storage because it contains a nested array.

        // evaluations of the public input

        Scalar.FE[2] memory public_evals;
        if ((proof.evals.optional_field_flags & 1) == 1) {
            public_evals = [proof.evals.public_evals.zeta, proof.evals.public_evals.zeta_omega];
        } else if (chunk_size > 1) {
            revert MissingPublicInputEvaluation();
        } else if (is_public_input_set) {
            // compute Lagrange base evaluation denominators

            // INFO: w is an iterator over the elements of the domain, we want to take N elements
            // where N is the length of the public input.
            Scalar.FE[] memory w = new Scalar.FE[](public_input.length);
            Scalar.FE[] memory zeta_minus_x = new Scalar.FE[](public_input.length * 2);

            Scalar.FE w_i = Scalar.one();
            for (uint256 i = 0; i < public_input.length; i++) {
                w[i] = w_i;
                zeta_minus_x[i] = zeta.sub(w_i).inv();
                zeta_minus_x[i + public_input.length] = zetaw.sub(w_i).inv();
                w_i = w_i.mul(index.domain_gen);
            }

            // 23. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            // NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
            if (public_input.length == 0) {
                public_evals = [Scalar.zero(), Scalar.zero()];
            } else {
                Scalar.FE pe_zeta = Scalar.zero();
                Scalar.FE size_inv = Scalar.from(index.domain_size).inv();
                for (uint256 i = 0; i < public_input.length; i++) {
                    // pe_zeta = pe_zeta - l*p*w_i
                    pe_zeta = pe_zeta.add(zeta_minus_x[i].neg().mul(public_input[i]).mul(w[i]));
                }

                // pe_zeta = pe_zeta * (zeta1 - 1) * domain_size_inv
                pe_zeta = pe_zeta.mul(zeta1.sub(Scalar.one())).mul(size_inv);

                Scalar.FE pe_zetaOmega = Scalar.zero();
                for (uint256 i = 0; i < public_input.length; i++) {
                    // pe_zetaOmega = pe_zetaOmega - l*p*w_i
                    pe_zetaOmega =
                        pe_zetaOmega.add(zeta_minus_x[i + public_input.length].neg().mul(public_input[i]).mul(w[i]));
                }
                // pe_zetaOmega = pe_zetaOmega * (zetaw^(domain_size) - 1) * domain_size_inv
                pe_zetaOmega = pe_zetaOmega.mul(zetaw.pow(index.domain_size).sub(Scalar.one())).mul(size_inv);

                public_evals = [pe_zeta, pe_zetaOmega];
            }
        } else {
            revert MissingPublicInputEvaluation();
        }

        // 24. Absorb the unique evaluation of ft
        scalar_sponge.absorb_scalar(proof.ft_eval1);

        // 25. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
        //~~ * the public polynomial
        //~~ * z
        //~~ * generic selector
        //~~ * poseidon selector
        //~~ * the 15 register/witness
        //~~ * 6 sigmas evaluations (the last one is not evaluated)
        scalar_sponge.absorb_scalar(public_evals[0]);
        scalar_sponge.absorb_scalar(public_evals[1]);
        scalar_sponge.absorb_evaluations(proof.evals);

        // 26. Sample v prime with the scalar sponge and derive v
        ScalarChallenge memory v_chal = ScalarChallenge(scalar_sponge.challenge_scalar());
        Scalar.FE v = v_chal.to_field(endo_r);

        // 27. Sample u prime with the scalar sponge and derive u
        ScalarChallenge memory u_chal = ScalarChallenge(scalar_sponge.challenge_scalar());
        Scalar.FE u = u_chal.to_field(endo_r);

        // 28. Create a list of all polynomials that have an evaluation proof
        //ProofEvaluations memory evals = proof.evals.combine_evals(powers_of_eval_points_for_chunks);
        // INFO: There's only one evaluation per polynomial so there's nothing to combine
        ProofEvaluations memory evals = proof.evals;

        // 29. Compute the evaluation of $ft(\zeta)$.
        Scalar.FE permutation_vanishing_poly =
            Polynomial.eval_vanishes_on_last_n_rows(index.domain_gen, index.domain_size, index.zk_rows, zeta);
        Scalar.FE zeta1m1 = zeta1.sub(Scalar.one());

        AlphasIterator memory alpha_pows = all_alphas.get_alphas(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);
        Scalar.FE alpha0 = alpha_pows.it_next();
        Scalar.FE alpha1 = alpha_pows.it_next();
        Scalar.FE alpha2 = alpha_pows.it_next();

        // initial value
        Scalar.FE ft_eval0 =
            evals.w[PERMUTS - 1].zeta.add(gamma).mul(evals.z.zeta_omega).mul(alpha0).mul(permutation_vanishing_poly);

        // map and reduction
        for (uint256 i = 0; i < PERMUTS - 1; i++) {
            ft_eval0 = ft_eval0.mul(beta.mul(evals.s[i].zeta).add(evals.w[i].zeta).add(gamma)); // reduction
        }

        ft_eval0 = ft_eval0.sub(public_evals[0]);

        // initial value
        Scalar.FE ev = alpha0.mul(permutation_vanishing_poly).mul(evals.z.zeta);

        // zip w and shift, map and reduction
        for (uint256 i = 0; i < Utils.min(evals.w.length, index.shift.length); i++) {
            ev = ev.mul(gamma.add(beta.mul(zeta).mul(index.shift[i])).add(evals.w[i].zeta)); // reduction
        }
        ft_eval0 = ft_eval0.sub(ev);

        Scalar.FE numerator = zeta1m1.mul(alpha1).mul(zeta.sub(index.w)).add(
            zeta1m1.mul(alpha2).mul(zeta.sub(Scalar.one()))
        ).mul(Scalar.one().sub(evals.z.zeta));

        Scalar.FE denominator = zeta.sub(index.w).mul(zeta.sub(Scalar.one())).inv();

        ft_eval0 = ft_eval0.add(numerator.mul(denominator));

        ExprConstants memory constants =
            ExprConstants(alpha, beta, gamma, joint_combiner_field, index.endo, index.zk_rows);

        Scalar.FE vanishing_eval = evaluate_vanishing_polynomial(index.domain_gen, index.domain_size, zeta);

        ft_eval0 = ft_eval0.sub(
            evaluate(
                index.linearization.constant_term,
                index.domain_gen,
                index.domain_size,
                zeta,
                vanishing_eval,
                evals,
                constants
            )
        );

        RandomOracles memory oracles = RandomOracles(
            joint_combiner,
            joint_combiner_field,
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
            vanishing_eval
        );

        return Result(digest, oracles, public_evals, powers_of_eval_points_for_chunks, zeta1, ft_eval0);
    }

    struct RandomOracles {
        ScalarChallenge joint_combiner;
        Scalar.FE joint_combiner_field;
        Scalar.FE beta;
        Scalar.FE gamma;
        ScalarChallenge alpha_chal;
        Scalar.FE alpha;
        Scalar.FE zeta;
        Scalar.FE v;
        Scalar.FE u;
        ScalarChallenge zeta_chal;
        ScalarChallenge v_chal;
        ScalarChallenge u_chal;
        Scalar.FE vanishing_eval;
    }

    struct Result {
        // INFO: sponges and all_alphas are stored in storage

        // the digest of the scalar sponge
        Scalar.FE digest;
        // challenges produced
        RandomOracles oracles;
        // public polynomial evaluations
        Scalar.FE[2] public_evals;
        // zeta^n and (zeta * omega)^n
        PointEvaluations powers_of_eval_points_for_chunks;
        // pre-computed zeta^n
        Scalar.FE zeta1;
        // the evaluation f(zeta) - t(zeta) * Z_H(zeta)
        Scalar.FE ft_eval0;
    }

    struct ScalarChallenge {
        Scalar.FE chal;
    }

    function to_field_with_length(ScalarChallenge memory self, uint256 length_in_bits, Scalar.FE endo_coeff)
        internal
        pure
        returns (Scalar.FE)
    {
        uint64[] memory r = get_limbs_64(Scalar.FE.unwrap(self.chal));
        Scalar.FE a = Scalar.from(2);
        Scalar.FE b = Scalar.from(2);

        Scalar.FE one = Scalar.from(1);
        Scalar.FE neg_one = one.neg();

        // (0..length_in_bits / 2).rev()
        for (uint256 _i = length_in_bits / 2; _i >= 1; _i--) {
            uint64 i = uint64(_i) - 1;
            a = a.double();
            b = b.double();

            uint64 r_2i = get_bit(r, 2 * i);
            Scalar.FE s = r_2i == 0 ? neg_one : one;

            if (get_bit(r, 2 * i + 1) == 0) {
                b = b.add(s);
            } else {
                a = a.add(s);
            }
        }

        return a.mul(endo_coeff).add(b);
    }

    function to_field(ScalarChallenge memory self, Scalar.FE endo_coeff) internal pure returns (Scalar.FE) {
        uint64 length_in_bits = 64 * CHALLENGE_LENGTH_IN_LIMBS;
        return self.to_field_with_length(length_in_bits, endo_coeff);
    }

    function get_bit(uint64[] memory limbs_lsb, uint64 i) internal pure returns (uint64) {
        uint64 limb = i / 64;
        uint64 j = i % 64;
        return (limbs_lsb[limb] >> j) & 1;
    }

    /// @notice Decomposes `n` into 64 bit limbs, less significant first
    function get_limbs_64(uint256 n) internal pure returns (uint64[] memory limbs) {
        uint256 len = 256 / 64;
        uint128 mask_64 = (1 << 64) - 1;

        limbs = new uint64[](len);
        for (uint256 i = 0; i < len; i++) {
            limbs[i] = uint64(n & mask_64);
            n >>= 64;
        }
    }

    /// @notice Recomposes 64-bit `limbs` into a bigint, less significant first
    function from_limbs_64(uint64[] memory limbs) internal pure returns (uint256 n_rebuilt) {
        n_rebuilt = 0;
        for (uint64 i = 0; i < limbs.length; i++) {
            n_rebuilt += limbs[i] << (64 * i);
        }
    }
}
