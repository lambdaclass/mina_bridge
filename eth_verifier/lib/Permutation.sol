// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";

using {Scalar.sub, Scalar.mul, Scalar.pow} for Scalar.FE;

/// @notice valuates the polynomial
/// @notice (x - w^{n - i}) * (x - w^{n - i + 1}) * ... * (x - w^{n - 1})
function eval_vanishes_on_last_n_rows(Scalar.FE domain_gen, uint256 domain_size, uint256 i, Scalar.FE x)
    pure
    returns (Scalar.FE acc)
{
    if (i == 0) {
        return Scalar.one();
    }
    Scalar.FE term = domain_gen.pow(domain_size - i);
    acc = x.sub(term);
    for (uint256 _j = 0; _j < i - 1; _j++) {
        term = term.mul(domain_gen);
        acc = acc.mul(x.sub(term));
    }
}
