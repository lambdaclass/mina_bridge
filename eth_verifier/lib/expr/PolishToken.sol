// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Expr.sol";
import "./ExprConstants.sol";
import "../bn254/Fields.sol";
import "../Permutation.sol";

using {Scalar.mul, Scalar.sub, Scalar.pow, Scalar.inv} for Scalar.FE;

// PolishToken is a tagged union type, whose variants can hold different data types.
// In Rust this can be implemented as an enum, in Typescript as a discriminated union.
//
// Here we'll use a struct, which will hold the `variant` tag as an enum and the
// `data` as bytes. The struct will be discriminated over its `variant` and after
// we can decode the bytes into the corresponding data type.

struct PolishToken {
    PolishTokenVariant variant;
    bytes data;
}

function evaluate(
    PolishToken[] memory toks,
    Scalar.FE d_gen,
    uint d_size,
    Scalar.FE pt,
    ProofEvaluations memory evals,
    ExprConstants memory c
) pure returns (Scalar.FE) {
    Scalar.FE[] stack = new Scalar.FE[](toks.length);
    uint stack_next = 0; // will keep track of last stack element's index
    Scalar.FE[] cache = new Scalar.FE[](toks.length);
    // WARN: Both arrays allocate the maximum memory the'll ever use, but it's
    // WARN: pretty unlikely they'll need it all.

    uint skip_count = 0;

    for (uint i = 0; i < toks.length; i++) {
        if (skip_count > 0) {
            skip_count -= 1;
            continue;
        }

        PolishTokenVariant v = toks[i].variant;
        if (v == PolishTokenVariant.Alpha) {
            stack[stack_next] = c.alpha;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Beta) {
            stack[stack_next] = c.beta;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Gamma) {
            stack[stack_next] = c.gamma;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.JointCombiner) {
            stack[stack_next] = c.joint_combiner;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.EndoCoefficient) {
            stack[stack_next] = c.endo_coefficient;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Mds) {
            PolishTokenMds memory pos = abi.decode(v.data, (PolishTokenMds));
            stack[stack_next] = c.mds[pos.row + pos.col]; // FIXME: determine order
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.VanishesOnZeroKnowledgeAndPreviousRows ) {
            stack[stack_next] = eval_vanishes_on_last_n_rows(
                domain_gen,
                domain_size,
                c.zk_rows + 1,
                pt
            );
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.UnnormalizedLagrangeBasis) {
            PolishTokenUnnormalizedLagrangeBasis i = abi.decode(v.data, (PolishTokenUnnormalizedLagrangeBasis ));

            uint offset;
            if (i.zk_rows) {
                offset = -(c.zk_rows) + i.offset;
            } else {
                offset = i.offset;
            }

            stack[stack_next] = unnormalized_lagrange_basis(domain_gen, domain_size, offset, pt);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Literal) {
            PolishTokenLiteral x = abi.decode(v.data, (PolishTokenLiteral));
            stack[stack_next] = x;
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Dup) {
            stack[stack_next] = stack[stack_next - 1];
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Cell) {
            PolishTokenCell x = abi.decode(v.data, (PolishTokenCell));
            stack[stack_next] = stack[stack_next - 1];
            stack_next += 1;
            continue;
        }
    }
}

enum PolishTokenVariant {
    Alpha,
    Beta,
    Gamma,
    JointCombiner,
    EndoCoefficient,
    Mds,
    Literal,
    Cell,
    Dup,
    Pow,
    Add,
    Mul,
    Sub,
    VanishesOnZeroKnowledgeAndPreviousRows,
    UnnormalizedLagrangeBasis,
    Store,
    Load,
    // Skip the given number of tokens if the feature is enabled.
    SkipIf,
    // Skip the given number of tokens if the feature is disabled.
    SkipIfNot
}

struct PolishTokenMds {
    uint row;
    uint col;
}
type PolishTokenLiteral is Scalar.FE;
type PolishTokenCell is Variable;
type PolishTokenDup is uint;
type PolishTokenUnnormalizedLagrangeBasis is RowOffset;
type PolishTokenLoad is uint;
type PolishTokenSkipIf is uint;

// @notice Compute the ith unnormalized lagrange basis
function unnormalized_lagrange_basis(
    Scalar.FE domain_gen,
    uint domain_size,
    uint i,
    Scalar.FE pt
) pure returns (Scalar.FE) {
    Scalar.FE omega_i;
    if (i < 0) {
        omega_i = domain_gen.pow(-i).inv();
    } else {
        omega_i = domain_gen.pow(i);
    }

    return pt.pow(domain_size).sub(Scalar.one()).mul((pt.sub(omega_i)).inv());
}
