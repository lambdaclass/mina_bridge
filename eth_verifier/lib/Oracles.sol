// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";
import "./VerifierIndex.sol";
import "./Evaluations.sol";
import "./Alphas.sol";
import "./sponge/Sponge.sol";
import "./Commitment.sol";
import "./Proof.sol";

library Oracles {
    using {to_field_with_length, to_field} for ScalarChallenge;
    using {
        Scalar.add,
        Scalar.mul,
        Scalar.neg,
        Scalar.double,
        Scalar.pow
    } for Scalar.FE;
    using {AlphasLib.instantiate} for Alphas;
    using {
        KeccakSponge.reinit,
        KeccakSponge.absorb_base,
        KeccakSponge.absorb_scalar,
        KeccakSponge.absorb_commitment,
        KeccakSponge.challenge_base,
        KeccakSponge.challenge_scalar,
        KeccakSponge.digest_base,
        KeccakSponge.digest_scalar
    } for Sponge;

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

        Scalar.FE[2][] public_evals;
        if (proof.is_public_evals_set) {
            public_evals = [proof.evals.zeta, proof.evals.zeta_omega];
        } else if (chunk_size > 1) {
            // FIXME: error missing public input evaluation
        } else if (is_public_input_set) {
            // compute Lagrange base evaluation denominators

            Scalar.FE[] w = new Scalar.FE[](public_input.length);
            Scalar.FE[] zeta_minus_x = new Scalar.FE[](public_input.length*2);
            for (uint i = 0; i < public_input.length; i++) {
                Scalar.FE w_i = index.domain_gen.pow(i);
                w[i] = w_i;
                zeta_minus_x[i] = zeta.sub(w_i).inv();
                zeta_minus_x[i + public_input.length] = zetaw.sub(w_i).inv();
            }

            // evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            if (public_input.length == 0) {
                Scalar.FE[] zero = new Scalar.FE[](1);
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
                    .mul(zetaw.pow(n).sub(Scalar.from(1)))
                    .mul(size_inv);

                public_evals = [[pe_zeta], [pe_zetaOmega]];
            }
        } else {
            // FIXME: error missing public input evaluation
        }

        // TODO: absorb the unique evaluation of ft

        // -squeeze challenges-

        //~ 28. Create a list of all polynomials that have an evaluation proof.

        //~ 29. Compute the evaluation of $ft(\zeta)$.

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
