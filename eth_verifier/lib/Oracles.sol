// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./bn254/Fields.sol";
import "./VerifierIndex.sol";
import "./Evaluations.sol";
import "./Alphas.sol";
import "./sponge/Sponge.sol";
import "./Commitment.sol";
import "./Proof.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import {Utils} from "./Utils.sol";

library Oracles {
    using {to_field_with_length, to_field} for ScalarChallenge;
    using {instantiate, get_alphas} for Alphas;
    using {it_next} for AlphasIterator;
    using {
        KeccakSponge.reinit,
        KeccakSponge.absorb_base,
        KeccakSponge.absorb_scalar,
        KeccakSponge.absorb_scalar_multiple,
        KeccakSponge.absorb_g_single,
        KeccakSponge.absorb_evaluations,
        KeccakSponge.challenge_base,
        KeccakSponge.challenge_scalar,
        KeccakSponge.digest_base,
        KeccakSponge.digest_scalar
    } for KeccakSponge.Sponge;
    using {Proof.get_column_eval} for Proof.ProofEvaluations;

    uint64 internal constant CHALLENGE_LENGTH_IN_LIMBS = 2;

    error IncorrectCommitmentLength(string name, uint256 required_len, uint256 actual_len);
    error MissingPublicInputEvaluation();

    // This takes Kimchi's `oracles()` as reference.
    function fiat_shamir(
        Proof.ProverProof memory proof,
        VerifierIndexLib.VerifierIndex storage index,
        BN254.G1Point memory public_comm,
        uint256 public_input,
        bool is_public_input_set
    ) internal returns (Result memory) {
        uint256 chunk_size = index.domain_size < index.max_poly_size ? 1 : index.domain_size / index.max_poly_size;

        (uint256 _endo_q, uint256 endo_r) = BN254.endo_coeffs_g1();

        // 1. Setup the Fq-Sponge.
        KeccakSponge.Sponge memory base_sponge;
        base_sponge.reinit();

        // 2. Absorb the digest of the VerifierIndex.
        uint256 verifier_index_digest = VerifierIndexLib.verifier_digest(index);
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
        uint256 joint_combiner_field = joint_combiner.to_field(endo_r);

        // 8. If lookup is used, absorb commitments to the sorted polys:
        for (uint256 i = 0; i < proof.commitments.lookup_sorted.length; i++) {
            base_sponge.absorb_g_single(proof.commitments.lookup_sorted[i]);
        }

        // 9. Sample beta from the sponge
        uint256 beta = base_sponge.challenge_scalar();
        // 10. Sample gamma from the sponge
        uint256 gamma = base_sponge.challenge_scalar();

        // 11. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        base_sponge.absorb_g_single(proof.commitments.lookup_aggreg);

        // 12. Absorb the commitment to the permutation trace with the Fq-Sponge.
        base_sponge.absorb_g_single(proof.commitments.z_comm);

        // 13. Sample alpha prime
        ScalarChallenge memory alpha_chal = ScalarChallenge(base_sponge.challenge_scalar());

        // 14. Derive alpha using the endomorphism
        uint256 alpha = alpha_chal.to_field(endo_r);

        // 15. Enforce that the length of the $t$ commitment is of size 7.
        // INFO: We are assuming the prover is configured accordingly so this is always the case

        // 16. Absorb commitment to the quotient polynomial $t$.
        for (uint256 i = 0; i < proof.commitments.t_comm.length; i++) {
            base_sponge.absorb_g_single(proof.commitments.t_comm[i]);
        }

        // 17. Sample zeta prime
        ScalarChallenge memory zeta_chal = ScalarChallenge(base_sponge.challenge_scalar());
        // 18. Derive zeta using the endomorphism
        uint256 zeta = zeta_chal.to_field(endo_r);

        // 19. Setup a scalar sponge
        KeccakSponge.Sponge memory scalar_sponge;
        scalar_sponge.reinit();

        // 20. Absorb the digest of the previous sponge
        uint256 digest = base_sponge.digest_scalar();
        scalar_sponge.absorb_scalar(digest);

        // TODO: 21. Absorb the previous recursion challenges
        // INFO: our proofs won't have recursion for now, so we only need
        // to absorb the digest of an empty sponge. This will be hardcoded:
        scalar_sponge.absorb_scalar(Scalar.from(0x00C5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A4));

        // often used values
        uint256 zeta1 = Scalar.pow(zeta, index.domain_size);
        uint256 zetaw = Scalar.mul(zeta, index.domain_gen);
        uint256[] memory evaluation_points = new uint256[](2);
        evaluation_points[0] = zeta;
        evaluation_points[1] = zetaw;
        PointEvaluations memory powers_of_eval_points_for_chunks =
            PointEvaluations(Scalar.pow(zeta, index.max_poly_size), Scalar.pow(zetaw, index.max_poly_size));

        // TODO: 22. Compute evaluations for the previous recursion challenges
        // INFO: this isn't necessary for our current test proof

        // retrieve ranges for the powers of alphas
        Alphas storage all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);
        // WARN: all_alphas should be a clone of index.powers_of_alpha, not a reference.
        // in our case we can only have it storage because it contains a nested array.

        // evaluations of the public input

        uint256[2] memory public_evals;
        if ((proof.evals.optional_field_flags & 1) == 1) {
            public_evals = [proof.evals.public_evals.zeta, proof.evals.public_evals.zeta_omega];
        } else if (chunk_size > 1) {
            revert MissingPublicInputEvaluation();
        } else if (is_public_input_set) {
            // compute Lagrange base evaluation denominators

            // INFO: w is an iterator over the elements of the domain, we want to take N elements
            // where N is the length of the public input.
            uint256 w = Scalar.one();
            uint256[2] memory zeta_minus_x = [Scalar.inv(Scalar.sub(zeta, w)), Scalar.inv(Scalar.sub(zetaw, w))];

            // 23. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            // NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
            uint256 pe_zeta = Scalar.zero();
            uint256 size_inv = Scalar.inv(Scalar.from(index.domain_size));
            // pe_zeta = pe_zeta - l*p*w_i
            pe_zeta = Scalar.add(pe_zeta, Scalar.mul(Scalar.mul(Scalar.neg(zeta_minus_x[0]), public_input), w));

            // pe_zeta = pe_zeta * (zeta1 - 1) * domain_size_inv
            pe_zeta = Scalar.mul(Scalar.mul(pe_zeta, Scalar.sub(zeta1, 1)), size_inv);

            // pe_zetaOmega = pe_zetaOmega - l*p*w_i
            uint256 pe_zetaOmega = Scalar.mul(Scalar.mul(Scalar.neg(zeta_minus_x[1]), public_input), w);
            // pe_zetaOmega = pe_zetaOmega * (zetaw^(domain_size) - 1) * domain_size_inv
            pe_zetaOmega =
                Scalar.mul(pe_zetaOmega, Scalar.mul(Scalar.sub(Scalar.pow(zetaw, index.domain_size), 1), size_inv));

            public_evals = [pe_zeta, pe_zetaOmega];
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
        uint256 v = v_chal.to_field(endo_r);

        // 27. Sample u prime with the scalar sponge and derive u
        ScalarChallenge memory u_chal = ScalarChallenge(scalar_sponge.challenge_scalar());
        uint256 u = u_chal.to_field(endo_r);

        // 28. Create a list of all polynomials that have an evaluation proof
        //ProofEvaluations memory evals = proof.evals.combine_evals(powers_of_eval_points_for_chunks);
        // INFO: There's only one evaluation per polynomial so there's nothing to combine
        Proof.ProofEvaluations memory evals = proof.evals;

        // 29. Compute the evaluation of $ft(\zeta)$.
        uint256 permutation_vanishing_poly =
            Polynomial.eval_vanishes_on_last_n_rows(index.domain_gen, index.domain_size, index.zk_rows, zeta);
        uint256 zeta1m1 = Scalar.sub(zeta1, 1);

        AlphasIterator memory alpha_pows = all_alphas.get_alphas(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);
        uint256 alpha0 = alpha_pows.it_next();
        uint256 alpha1 = alpha_pows.it_next();
        uint256 alpha2 = alpha_pows.it_next();

        // initial value
        uint256 ft_eval0 = Scalar.mul(
            Scalar.mul(Scalar.mul(Scalar.add(evals.w[PERMUTS - 1].zeta, gamma), evals.z.zeta_omega), alpha0),
            permutation_vanishing_poly
        );

        // map and reduction
        for (uint256 i = 0; i < PERMUTS - 1; i++) {
            // reduction
            ft_eval0 =
                Scalar.mul(ft_eval0, Scalar.add(Scalar.add(Scalar.mul(beta, evals.s[i].zeta), evals.w[i].zeta), gamma));
        }

        ft_eval0 = Scalar.sub(ft_eval0, public_evals[0]);

        // initial value
        uint256 ev = Scalar.mul(Scalar.mul(alpha0, permutation_vanishing_poly), evals.z.zeta);

        // zip w and shift, map and reduction
        for (uint256 i = 0; i < Utils.min(evals.w.length, index.shift.length); i++) {
            ev = Scalar.mul(
                ev, Scalar.add(Scalar.add(gamma, Scalar.mul(Scalar.mul(beta, zeta), index.shift[i])), evals.w[i].zeta)
            ); // reduction
        }
        ft_eval0 = Scalar.sub(ft_eval0, ev);

        uint256 numerator = Scalar.mul(
            Scalar.add(
                Scalar.mul(Scalar.mul(zeta1m1, alpha1), Scalar.sub(zeta, index.w)),
                Scalar.mul(Scalar.mul(zeta1m1, alpha2), Scalar.sub(zeta, 1))
            ),
            Scalar.sub(1, evals.z.zeta)
        );
        uint256 denominator = Scalar.inv(Scalar.mul(Scalar.sub(zeta, index.w), Scalar.sub(zeta, 1)));
        ft_eval0 = Scalar.add(ft_eval0, Scalar.mul(numerator, denominator));

        ExprConstants memory constants =
            ExprConstants(alpha, beta, gamma, joint_combiner_field, index.endo, index.zk_rows);

        uint256 vanishing_eval =
            PolishTokenEvaluation.evaluate_vanishing_polynomial(index.domain_gen, index.domain_size, zeta);

        ft_eval0 = Scalar.sub(
            ft_eval0,
            PolishTokenEvaluation.evaluate(
                index.linearization, index.domain_gen, index.domain_size, zeta, vanishing_eval, evals, constants
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
        uint256 joint_combiner_field;
        uint256 beta;
        uint256 gamma;
        ScalarChallenge alpha_chal;
        uint256 alpha;
        uint256 zeta;
        uint256 v;
        uint256 u;
        ScalarChallenge zeta_chal;
        ScalarChallenge v_chal;
        ScalarChallenge u_chal;
        uint256 vanishing_eval;
    }

    struct Result {
        // INFO: sponges and all_alphas are stored in storage

        // the digest of the scalar sponge
        uint256 digest;
        // challenges produced
        RandomOracles oracles;
        // public polynomial evaluations
        uint256[2] public_evals;
        // zeta^n and (zeta * omega)^n
        PointEvaluations powers_of_eval_points_for_chunks;
        // pre-computed zeta^n
        uint256 zeta1;
        // the evaluation f(zeta) - t(zeta) * Z_H(zeta)
        uint256 ft_eval0;
    }

    struct ScalarChallenge {
        uint256 chal;
    }

    function to_field_with_length(ScalarChallenge memory self, uint256 length_in_bits, uint256 endo_coeff)
        internal
        pure
        returns (uint256)
    {
        uint256 r = self.chal;
        uint256 a = Scalar.from(2);
        uint256 b = Scalar.from(2);

        uint256 one = Scalar.from(1);
        uint256 neg_one = Scalar.neg(1);

        // (0..length_in_bits / 2).rev()
        for (uint256 _i = length_in_bits / 2; _i >= 1; _i--) {
            uint256 i = _i - 1;
            a = Scalar.double(a);
            b = Scalar.double(b);

            uint256 r_2i = (r >> (2 * i)) & 1;
            uint256 s = r_2i == 0 ? neg_one : one;

            if ((r >> (2 * i + 1)) & 1 == 0) {
                b = Scalar.add(b, s);
            } else {
                a = Scalar.add(a, s);
            }
        }

        return Scalar.add(Scalar.mul(a, endo_coeff), b);
    }

    function to_field(ScalarChallenge memory self, uint256 endo_coeff) internal pure returns (uint256) {
        uint64 length_in_bits = 64 * CHALLENGE_LENGTH_IN_LIMBS;
        return self.to_field_with_length(length_in_bits, endo_coeff);
    }
}
