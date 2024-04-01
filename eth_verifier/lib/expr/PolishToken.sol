// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Expr.sol";
import "./ExprConstants.sol";
import "../bn254/Fields.sol";
import "../Proof.sol";
import "../sponge/Sponge.sol";

using {Scalar.add, Scalar.mul, Scalar.sub, Scalar.pow, Scalar.inv} for Scalar.FE;

// PolishToken is a tagged union type, whose variants can hold different data types.
// In Rust this can be implemented as an enum, in Typescript as a discriminated union.
//
// Here we'll use a struct, which will hold the `variant` tag as an enum and the
// `data` as bytes. The struct will be discriminated over its `variant` and after
// we can decode the bytes into the corresponding data type.
//
// The idea was also to have type aliases for each data type that's contained in
// every variant (for example, the MDS variant contains a struct with two fields,
// so we should set an alias to a structure type like that, or directly define
// a struct with that shape, in this case PolishTokenMds was defined below).

struct PolishToken {
    PolishTokenVariant variant;
    bytes data;
}

function evaluate(
    PolishToken[] memory toks,
    Scalar.FE domain_gen,
    uint256 domain_size,
    Scalar.FE pt,
    NewProofEvaluations memory evals,
    ExprConstants memory c
) view returns (Scalar.FE) {
    Scalar.FE[] memory stack = new Scalar.FE[](toks.length);
    uint256 stack_next = 0; // will keep track of last stack element's index
    Scalar.FE[] memory cache = new Scalar.FE[](toks.length);
    uint256 cache_next = 0; // will keep track of last cache element's index
    // WARN: Both arrays allocate the maximum memory they will ever use, but it's
    // WARN: pretty unlikely they'll need it all.

    uint256 skip_count = 0;

    for (uint256 i = 0; i < toks.length; i++) {
        if (skip_count > 0) {
            skip_count -= 1;
            continue;
        }

        PolishTokenVariant v = toks[i].variant;
        bytes memory v_data = toks[i].data;
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
            PolishTokenMds memory pos = abi.decode(v_data, (PolishTokenMds));
            stack[stack_next] = KeccakSponge.mds()[pos.row][pos.col];
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.VanishesOnZeroKnowledgeAndPreviousRows) {
            stack[stack_next] = Polynomial.eval_vanishes_on_last_n_rows(domain_gen, domain_size, c.zk_rows + 1, pt);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.UnnormalizedLagrangeBasis) {
            int256 offset = abi.decode(v_data, (int256));

            stack[stack_next] = unnormalized_lagrange_basis(domain_gen, domain_size, offset, pt);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Literal) {
            Scalar.FE x = abi.decode(v_data, (Scalar.FE));
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
            Variable memory x = abi.decode(v_data, (Variable));
            stack[stack_next] = evaluate_variable(x, evals);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Pow) {
            uint256 n = abi.decode(v_data, (uint256)); // WARN: different types
            stack[stack_next - 1] = stack[stack_next - 1].pow(n);
            continue;
        }
        if (v == PolishTokenVariant.Add) {
            // pop x and y
            Scalar.FE y = stack[stack_next - 1];
            stack_next -= 1;
            Scalar.FE x = stack[stack_next - 1];
            stack_next -= 1;

            // push result
            stack[stack_next] = x.add(y);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Mul) {
            // pop x and y
            Scalar.FE y = stack[stack_next - 1];
            stack_next -= 1;
            Scalar.FE x = stack[stack_next - 1];
            stack_next -= 1;

            // push result
            stack[stack_next] = x.mul(y);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Sub) {
            // pop x and y
            Scalar.FE y = stack[stack_next - 1];
            stack_next -= 1;
            Scalar.FE x = stack[stack_next - 1];
            stack_next -= 1;

            // push result
            stack[stack_next] = x.sub(y);
            stack_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Store) {
            Scalar.FE x = stack[stack_next - 1];

            cache[cache_next] = x;
            cache_next += 1;
            continue;
        }
        if (v == PolishTokenVariant.Load) {
            uint256 j = abi.decode(v_data, (uint256)); // WARN: different types
            Scalar.FE x = cache[j];

            stack[stack_next] = x;
            stack_next += 1;
            continue;
        }
        revert("unhandled polish token variant");
        // TODO: SkipIf, SkipIfNot
    }
    require(stack_next == 1);
    return stack[0];
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
    uint256 row;
    uint256 col;
}
// type PolishTokenLiteral is Scalar.FE; // can't do this, language limitation
// type PolishTokenCell is Variable; // can't do this, language limitation

type PolishTokenDup is uint256;

type PolishTokenPow is uint256;
// type PolishTokenUnnormalizedLagrangeBasis is RowOffset; // can't do this, language limitation

type PolishTokenLoad is uint256;

type PolishTokenSkipIf is uint256;
// TODO: maybe delete these types? Solidity only allows to define aliases
// (actually called "user-defined value types") over elementary value types like
// integers, bools.

// @notice Compute the ith unnormalized lagrange basis
function unnormalized_lagrange_basis(Scalar.FE domain_gen, uint256 domain_size, int256 i, Scalar.FE pt)
    view
    returns (Scalar.FE result)
{
    Scalar.FE omega_i;
    if (i < 0) {
        omega_i = domain_gen.pow(uint256(-i)).inv();
    } else {
        omega_i = domain_gen.pow(uint256(i));
    }

    result = evaluate_vanishing_polynomial(domain_gen, domain_size, pt);
    Scalar.FE sub_m_omega = pt.sub(omega_i);
    result = result.mul(sub_m_omega.inv());
}

// @notice evaluates the vanishing polynomial for this domain at tau.
// @notice for multiplicative subgroups, this polynomial is `z(X) = X^self.size - 1
function evaluate_vanishing_polynomial(Scalar.FE domain_gen, uint256 domain_size, Scalar.FE tau)
    pure
    returns (Scalar.FE)
{
    return tau.pow(domain_size).sub(Scalar.one());
}
