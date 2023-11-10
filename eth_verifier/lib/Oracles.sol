// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Fields.sol";
import "./VerifierIndex.sol";
import "./Evaluations.sol";
import "./Alphas.sol";

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

    uint64 internal constant CHALLENGE_LENGTH_IN_LIMBS = 2;

    function fiat_shamir(VerifierIndex storage index) public {
        // WARN: We'll skip the use of a sponge and generate challenges from pseudo-random numbers
        Scalar.FE endo_coeff = Scalar.from(0); // FIXME: not zero

        // Sample beta and gamma from the sponge
        Scalar.FE beta = challenge();
        Scalar.FE gamma = challenge();

        // Sample alpha prime
        ScalarChallenge memory alpha_chal = scalar_chal();
        // Derive alpha using the endomorphism
        Scalar.FE alpha = alpha_chal.to_field(endo_coeff);

        // Sample alpha prime
        ScalarChallenge memory zeta_chal = scalar_chal();
        // Derive alpha using the endomorphism
        Scalar.FE zeta = zeta_chal.to_field(endo_coeff);

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

        //~ 20. Compute evaluations for the previous recursion challenges. SKIP

        // retrieve ranges for the powers of alphas
        Alphas storage all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);

        // evaluations of the public input
        // if they are not present in the proof:
        //~ 21. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
        //

        // -squeeze challenges-

        //~ 28. Create a list of all polynomials that have an evaluation proof.

        //~ 29. Compute the evaluation of $ft(\zeta)$.

        // evaluate final polynomial (PolishToken)
        // combined inner prod
    }

    /// @notice creates a challenge frm hashing the current block timestamp.
    /// @notice this function is only going to be used for the demo and never in
    /// @notice a serious environment. DO NOT use this in any other case.
    function challenge() internal view returns (Scalar.FE) {
        Scalar.from(uint256(keccak256(abi.encode(block.timestamp))));
    }

    /// @notice creates a `ScaharChallenge` using `challenge()`.
    function scalar_chal() internal view returns (ScalarChallenge memory) {
        return ScalarChallenge(challenge());
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
