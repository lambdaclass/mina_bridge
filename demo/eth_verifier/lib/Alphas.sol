// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Fields.sol";

using {Scalar.mul} for Scalar.FE;

/// This type can be used to create a mapping between powers of alpha and constraint types.
/// See `default()` to create one (not implemented yet),
/// and `register()` to register a new mapping (not implemented yet).
/// Once you know the alpha value, you can convert this type to a `Alphas`.
///
/// Here alpha is a challenge generated by Fiat-Shamir and every constraint (in polynomial
/// form) will get multiplied by a power to make a linearly independent combination
/// (sometimes called the "main polynomial $f$"), of which soundness arguments can be made.
struct Alphas {
    /// The next power of alpha to use.
    /// The end result will be [1, alpha^(next_power - 1)]
    uint next_power;
    /// The mapping between constraint types and powers of alpha */
    mapping(ArgumentType => uint[2]) map;
    /// The powers of alpha: 1, alpha, alpha^2, ..
    /// The array is initially empty until powers are initialized.
    /// If not empty, you can't register new contraints.
    Scalar.FE[] alphas;
}

library AlphasLib {
    /// Instantiates the ranges with an actual field element `alpha`.
    /// Once you call this function, you cannot register new constraints.
    function instantiate(Alphas storage self, Scalar.FE alpha) internal {
        Scalar.FE last_power = Scalar.from(1);
        self.alphas.push(last_power);

        for (uint i = 1; i < self.next_power; i++) {
            last_power = last_power.mul(alpha);
            self.alphas.push(last_power);
        }
    }
}

enum ArgumentType {
    // Gate types
    GateZero,
    GateGeneric,
    GatePoseidon,
    GateCompleteAdd,
    GateVarBaseMul,
    GateEndoMul,
    GateEndoMulScalar,
    GateLookup,
    GateCairoClaim,
    GateCairoInstruction,
    GateCairoFlags,
    GateCairoTransition,
    GateRangeCheck0,
    GateRangeCheck1,
    GateForeignFieldAdd,
    GateForeignFieldMul,
    GateXor16,
    GateRot64,
    // Permutation
    Permutation

    // Lookup
    //Lookup
}
