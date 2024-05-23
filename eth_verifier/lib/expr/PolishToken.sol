// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Expr.sol";
import "./ExprConstants.sol";
import "../bn254/Fields.sol";
import "../Proof.sol";
import "../sponge/Sponge.sol";
import {Polynomial} from "../Polynomial.sol";
import {PointEvaluations} from "../Evaluations.sol";

library PolishTokenEvaluation {
    function evaluate(
        Linearization storage linearization,
        uint256 domain_gen,
        uint256 domain_size,
        uint256 pt,
        uint256 vanishing_eval,
        Proof.ProofEvaluations memory evals,
        ExprConstants memory c
    ) internal view returns (uint256) {
        uint256[] memory stack = new uint256[](linearization.total_variants_len);
        uint256 stack_next = 0; // will keep track of last stack element's index
        uint256[] memory cache = new uint256[](linearization.total_variants_len);
        uint256 cache_next = 0; // will keep track of last cache element's index
        // WARN: Both arrays allocate the maximum memory they will ever use, but it's
        // WARN: pretty unlikely they'll need it all.

        uint256 next_mds_index = 0;
        uint256 next_literals_index = 0;
        uint256 next_pows_index = 0;
        uint256 next_offsets_index = 0;
        uint256 next_loads_index = 0;

        for (uint256 i = 0; i < linearization.total_variants_len; i++) {
            uint256 byte_index = 31 - (i % 32);
            uint256 word_index = i / 32;
            uint256 variant = (linearization.variants[word_index] >> (byte_index * 8)) & 0xFF;

            // Alpha
            if (variant == 0) {
                stack[stack_next] = c.alpha;
                stack_next += 1;
                continue;
            }
            // Beta
            if (variant == 1) {
                stack[stack_next] = c.beta;
                stack_next += 1;
                continue;
            }
            // Gamma
            if (variant == 2) {
                stack[stack_next] = c.gamma;
                stack_next += 1;
                continue;
            }
            // JointCombiner
            if (variant == 3) {
                stack[stack_next] = c.joint_combiner;
                stack_next += 1;
                continue;
            }
            // EndoCoefficient
            if (variant == 4) {
                stack[stack_next] = c.endo_coefficient;
                stack_next += 1;
                continue;
            }
            // Mds
            if (variant == 5) {
                uint256 row = linearization.mds[next_mds_index];
                uint256 col = linearization.mds[next_mds_index + 1];
                next_mds_index += 2;

                stack[stack_next] = KeccakSponge.mds()[row][col];
                stack_next += 1;
                continue;
            }
            // Literal
            if (variant == 6) {
                uint256 literal = linearization.literals[next_literals_index];
                next_literals_index += 1;

                stack[stack_next] = literal;
                stack_next += 1;
                continue;
            }
            // Dup
            if (variant == 7) {
                stack[stack_next] = stack[stack_next - 1];
                stack_next += 1;
                continue;
            }
            // Pow
            if (variant == 8) {
                uint256 n = linearization.pows[next_pows_index];
                next_pows_index += 1;

                stack[stack_next - 1] = Scalar.pow(stack[stack_next - 1], n);
                continue;
            }
            // Add
            if (variant == 9) {
                // pop x and y
                uint256 y = stack[stack_next - 1];
                stack_next -= 1;
                uint256 x = stack[stack_next - 1];
                stack_next -= 1;

                // push result
                stack[stack_next] = Scalar.add(x, y);
                stack_next += 1;
                continue;
            }
            // Mul
            if (variant == 10) {
                // pop x and y
                uint256 y = stack[stack_next - 1];
                stack_next -= 1;
                uint256 x = stack[stack_next - 1];
                stack_next -= 1;

                // push result
                stack[stack_next] = Scalar.mul(x, y);
                stack_next += 1;
                continue;
            }
            // Sub
            if (variant == 11) {
                // pop x and y
                uint256 y = stack[stack_next - 1];
                stack_next -= 1;
                uint256 x = stack[stack_next - 1];
                stack_next -= 1;

                // push result
                stack[stack_next] = Scalar.sub(x, y);
                stack_next += 1;
                continue;
            }
            // VanishesOnZeroKnowledgeAndPreviousRows
            if (variant == 12) {
                stack[stack_next] = Polynomial.eval_vanishes_on_last_n_rows(domain_gen, domain_size, c.zk_rows + 1, pt);
                stack_next += 1;
                continue;
            }
            // UnnormalizedLagrangeBasis
            if (variant == 13) {
                int256 offset = linearization.offsets[next_offsets_index];
                next_offsets_index += 1;

                stack[stack_next] = unnormalized_lagrange_basis(domain_gen, vanishing_eval, offset, pt);
                stack_next += 1;
                continue;
            }
            // Store
            if (variant == 14) {
                uint256 x = stack[stack_next - 1];

                cache[cache_next] = x;
                cache_next += 1;
                continue;
            }
            // Load
            if (variant == 15) {
                uint256 j = linearization.loads[next_loads_index];
                next_loads_index += 1;

                uint256 x = cache[j];
                stack[stack_next] = x;
                stack_next += 1;
                continue;
            }
            // Cell
            if (variant >= 16) {
                // check msb for row:
                bool curr = variant & 0x80 == 0;

                // get eval from column id (see serializer)
                uint256 col_id = (variant & (0x80 - 1)) - 16;
                PointEvaluations memory point_eval = Proof.evaluate_column_by_id(evals, col_id);
                uint256 eval;
                if (curr) {
                    eval = point_eval.zeta;
                } else {
                    eval = point_eval.zeta_omega;
                }

                stack[stack_next] = eval;
                stack_next += 1;
                continue;
            }
            revert("unhandled polish token variant");
        }

        require(stack_next == 1, "Polish token stack didn't evaluate fully");
        return stack[0];
    }
    // @notice Compute the ith unnormalized lagrange basis

    function unnormalized_lagrange_basis(uint256 domain_gen, uint256 vanishing_eval, int256 i, uint256 pt)
        internal
        view
        returns (uint256 result)
    {
        uint256 omega_i;
        if (i < 0) {
            omega_i = Scalar.inv(Scalar.pow(domain_gen, uint256(-i)));
        } else {
            omega_i = Scalar.pow(domain_gen, uint256(i));
        }

        uint256 sub_m_omega = Scalar.sub(pt, omega_i);
        result = Scalar.mul(vanishing_eval, Scalar.inv(sub_m_omega));
    }

    // @notice evaluates the vanishing polynomial for this domain at tau.
    // @notice for multiplicative subgroups, this polynomial is `z(X) = X^self.size - 1
    function evaluate_vanishing_polynomial(uint256 domain_gen, uint256 domain_size, uint256 tau)
        internal
        view
        returns (uint256)
    {
        return Scalar.sub(Scalar.pow(tau, domain_size), 1);
    }
}
