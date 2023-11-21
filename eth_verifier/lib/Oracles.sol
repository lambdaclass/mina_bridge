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
    using {
        Scalar.neg,
        Scalar.add,
        Scalar.sub,
        Scalar.mul,
        Scalar.inv,
        Scalar.double,
        Scalar.pow
    } for Scalar.FE;
    using {AlphasLib.instantiate, AlphasLib.get_alphas} for Alphas;
    using {
        KeccakSponge.reinit,
        KeccakSponge.absorb_base,
        KeccakSponge.absorb_scalar,
        KeccakSponge.absorb_scalar_multiple,
        KeccakSponge.absorb_commitment,
        KeccakSponge.absorb_evaluations,
        KeccakSponge.challenge_base,
        KeccakSponge.challenge_scalar,
        KeccakSponge.digest_base,
        KeccakSponge.digest_scalar
    } for Sponge;
    using {combine_evals} for ProofEvaluationsArray;

    uint64 internal constant CHALLENGE_LENGTH_IN_LIMBS = 2;

    function fiat_shamir(
        ProverProof memory proof,
        VerifierIndex storage index,
        PolyComm memory public_comm,
        Scalar.FE[] memory public_input,
        bool is_public_input_set,
        Sponge storage base_sponge,
        Sponge storage scalar_sponge
    ) public {
        uint chunk_size = index.domain_size < index.max_poly_size ?
            1 : index.domain_size / index.max_poly_size;

        Scalar.FE endo_coeff = Scalar.from(0); // FIXME: not zero

        base_sponge.reinit();

        base_sponge.absorb_base(verifier_digest(index));
        base_sponge.absorb_commitment(public_comm);

        // TODO: absorb the commitments to the registers / witness columns
        // TODO: lookups

        // Sample beta and gamma from the sponge
        Scalar.FE beta = base_sponge.challenge_scalar();
        Scalar.FE gamma = base_sponge.challenge_scalar();

        // Sample alpha prime
        ScalarChallenge memory alpha_chal = ScalarChallenge(base_sponge.challenge_scalar());
        // Derive alpha using the endomorphism
        Scalar.FE alpha = alpha_chal.to_field(endo_coeff);

        // TODO: enforce length of the $t$ commitment

        // TODO: absorb commitment to the quotient poly

        // Sample alpha prime
        ScalarChallenge memory zeta_chal = ScalarChallenge(base_sponge.challenge_scalar());
        // Derive alpha using the endomorphism
        Scalar.FE zeta = zeta_chal.to_field(endo_coeff);

        scalar_sponge.reinit();
        scalar_sponge.absorb_scalar(base_sponge.digest_scalar());

        // often used values
        Scalar.FE zeta1 = zeta.pow(index.domain_size);
        Scalar.FE zetaw = zeta.mul(index.domain_gen);
        Scalar.FE[] memory evaluation_points = new Scalar.FE[](2);
        evaluation_points[0] = zeta;
        evaluation_points[1] = zetaw;
        PointEvaluations
            memory powers_of_eval_points_for_chunks = PointEvaluations(
                zeta.pow(index.max_poly_size),
                zetaw.pow(index.max_poly_size)
            );

        // TODO: Compute evaluations for the previous recursion challenges

        // retrieve ranges for the powers of alphas
        Alphas storage all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);

        // evaluations of the public input

        Scalar.FE[][2] memory public_evals;
        if (proof.evals.is_public_evals_set) {
            public_evals = [proof.evals.public_evals.zeta, proof.evals.public_evals.zeta_omega];
        } else if (chunk_size > 1) {
            // FIXME: error missing public input evaluation
        } else if (is_public_input_set) {
            // compute Lagrange base evaluation denominators

            Scalar.FE[] memory w = new Scalar.FE[](public_input.length);
            Scalar.FE[] memory zeta_minus_x = new Scalar.FE[](public_input.length*2);
            for (uint i = 0; i < public_input.length; i++) {
                Scalar.FE w_i = index.domain_gen.pow(i);
                w[i] = w_i;
                zeta_minus_x[i] = zeta.sub(w_i).inv();
                zeta_minus_x[i + public_input.length] = zetaw.sub(w_i).inv();
            }

            // evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            if (public_input.length == 0) {
                Scalar.FE[] memory zero = new Scalar.FE[](1);
                zero[0] = Scalar.zero();
                public_evals = [zero, zero];
            } else {
                Scalar.FE pe_zeta = Scalar.zero();
                for (uint i = 0; i < public_input.length; i++) {
                    Scalar.FE p = public_input[i];
                    Scalar.FE l = zeta_minus_x[i];
                    Scalar.FE w_i = w[i];

                    pe_zeta = pe_zeta.add(l.neg().mul(p).mul(w_i));
                }

                Scalar.FE size_inv = Scalar.from(index.domain_size).inv();
                pe_zeta = pe_zeta.mul(zeta1.sub(Scalar.from(1))).mul(size_inv);

                Scalar.FE pe_zetaOmega = Scalar.zero();
                for (uint i = 0; i < public_input.length; i++) {
                    Scalar.FE p = public_input[i];
                    Scalar.FE l = zeta_minus_x[i + public_input.length];
                    Scalar.FE w_i = w[i];

                    pe_zetaOmega = pe_zetaOmega.add(l.neg().mul(p).mul(w_i));
                }
                pe_zetaOmega = pe_zetaOmega
                    .mul(zetaw.pow(index.domain_size).sub(Scalar.from(1)))
                    .mul(size_inv);

                Scalar.FE[] memory pe_zeta_arr = new Scalar.FE[](1);
                Scalar.FE[] memory pe_zetaOmega_arr = new Scalar.FE[](1);
                pe_zeta_arr[0] = pe_zeta;
                pe_zetaOmega_arr[0] = pe_zetaOmega;
                public_evals = [pe_zeta_arr, pe_zetaOmega_arr];
            }
        } else {
            // FIXME: error missing public input evaluation
        }

        // TODO: absorb the unique evaluation of ft

        // absorb the public evals
        scalar_sponge.absorb_scalar_multiple(public_evals[0]);
        scalar_sponge.absorb_scalar_multiple(public_evals[1]);
        scalar_sponge.absorb_evaluations(proof.evals);

        ScalarChallenge memory v_chal = ScalarChallenge(scalar_sponge.challenge_scalar());
        Scalar.FE v = v_chal.to_field(endo_coeff);

        ScalarChallenge memory u_chal = ScalarChallenge(scalar_sponge.challenge_scalar());
        Scalar.FE u = u_chal.to_field(endo_coeff);

        ProofEvaluations memory evals = proof.evals.combine_evals(powers_of_eval_points_for_chunks);

        // compute the evaluation of $ft(\zeta)$.
        Scalar.FE ft_eval0;
        // FIXME: evaluate permutation vanishing poly in zeta
        Scalar.FE permutation_vanishing_poly = Scalar.from(1);
        Scalar.FE zeta1m1 = zeta1.sub(Scalar.from(1));

        uint permutation_constraints = 3;
        Scalar.FE[] memory alpha_pows = all_alphas.get_alphas(ArgumentType.Permutation, permutation_constraints);
        Scalar.FE alpha0 = alpha_pows[0];
        Scalar.FE alpha1 = alpha_pows[1];
        Scalar.FE alpha2 = alpha_pows[2];
        // WARN: alpha_powers should be an iterator and alphai = alpha_powers.next(), for i = 0,1,2.

        Scalar.FE ft_eval0 = evals.w[Constants.PERMUTS - 1].zeta.add(gamma)
            .mul(evals.z.zeta_omega)
            .mul(alpha0)
            .mul(permutation_vanishing_poly);

        for (uint i = 0; i < permuts - 1; i++) {
            Scalar.FE w = evals.w[i];
            Scalar.FE s = evals.s[i];
            ft_eval0 = init.mul(beta.mul(s.zeta).add(w.zeta).add(gamma));
        }

        ft_eval0 = ft_eval0.sub(
            Polynomial.build_and_eval(
                public_evals[0],
                powers_of_eval_points_for_chunks.zeta
        ));

        Scalar.FE ev = alpha0.mul(permutation_vanishing_poly).mul(evals.z.zeta);
        for (uint i = 0; i < permuts; i++) {
            Scalar.FE w = evals.w[i];
            Scalar.FE s = index.shift[i];

            ev = ev.mul(gamma.add(beta.mul(zeta).mul(s)).add(w.zeta));
        }
        ft_eval0 = ft_eval0.sub(ev);

        Scalar.FE numerator = zeta1m1.mul(alpha1).mul(zeta.sub(index.w))
            .add(zeta1m1.mul(alpha2).mul(zeta.sub(Scalar.from(1))))
            .mul(Scalar.from(1).sub(evals.z.zeta));

        Scalar.FE denominator = zeta.sub(index.w).mul(zeta.sub(Scalar.from(1))).inv();

        ft_eval0 = ft_eval0.add(numerator.mul(denominator));

        // evaluate final polynomial (PolishToken)
        // combined inner prod
    }

    struct ScalarChallenge {
        Scalar.FE chal;
    }

    function to_field_with_length(
        ScalarChallenge memory self,
        uint length_in_bits,
        Scalar.FE endo_coeff
    ) internal pure returns (Scalar.FE) {
        uint64[] memory r = get_limbs_64(Scalar.FE.unwrap(self.chal));
        Scalar.FE a = Scalar.from(2);
        Scalar.FE b = Scalar.from(2);

        Scalar.FE one = Scalar.from(1);
        Scalar.FE neg_one = one.neg();

        for (uint64 i = 0; i < length_in_bits / 2; i++) {
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

    function to_field(
        ScalarChallenge memory self,
        Scalar.FE endo_coeff
    ) internal pure returns (Scalar.FE) {
        uint64 length_in_bits = 64 * CHALLENGE_LENGTH_IN_LIMBS;
        return self.to_field_with_length(length_in_bits, endo_coeff);
    }

    function get_bit(
        uint64[] memory limbs_lsb,
        uint64 i
    ) internal pure returns (uint64) {
        uint64 limb = i / 64;
        uint64 j = i % 64;
        return (limbs_lsb[limb] >> j) & 1;
    }

    /// @notice Decomposes `n` into 64 bit limbs, less significant first
    function get_limbs_64(
        uint256 n
    ) internal pure returns (uint64[] memory limbs) {
        uint len = 256 / 64;
        uint128 mask_64 = (1 << 64) - 1;

        limbs = new uint64[](len);
        for (uint i = 0; i < len; i++) {
            limbs[i] = uint64(n & mask_64);
            n >>= 64;
        }

        return limbs;
    }

    /// @notice Recomposes 64-bit `limbs` into a bigint, less significant first
    function from_limbs_64(
        uint64[] memory limbs
    ) internal pure returns (uint256 n_rebuilt) {
        n_rebuilt = 0;
        for (uint i = 0; i < limbs.length; i++) {
            n_rebuilt += limbs[i] << (64 * i);
        }
    }
}
