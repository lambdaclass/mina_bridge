// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Scalar} from "./bn254/Fields.sol";
import {Utils} from "./Utils.sol";

library Polynomial {
    using {Scalar.add, Scalar.mul, Scalar.sub, Scalar.pow, Scalar.neg} for Scalar.FE;

    struct Dense {
        Scalar.FE[] coeffs;
    }

    // @notice evaluates via Horner's method.
    // @warn this function can not be used with the empty polynomial.
    function build_and_eval(Scalar.FE[] memory coeffs, Scalar.FE x) internal pure returns (Scalar.FE result) {
        result = coeffs[coeffs.length - 1];
        if (coeffs.length == 1) {
            return result;
        }
        uint256 i = coeffs.length - 1;
        while (i != 0) {
            --i;
            result = result.mul(x).add(coeffs[i]);
        }
    }

    function sub(Dense memory self, Dense memory other) internal pure returns (Dense memory) {
        uint256 n = Utils.min(self.coeffs.length, other.coeffs.length);
        Scalar.FE[] memory coeffs_self_sub_other = new Scalar.FE[](n);
        for (uint256 i = 0; i < n; i++) {
            coeffs_self_sub_other[i] = self.coeffs[i].sub(other.coeffs[i]);
        }

        return Dense(coeffs_self_sub_other);
    }

    // @notice evaluates the polynomial
    // @notice (x - w^{n - i}) * (x - w^{n - i + 1}) * ... * (x - w^{n - 1})
    function eval_vanishes_on_last_n_rows(Scalar.FE domain_gen, uint256 domain_size, uint256 i, Scalar.FE x)
        internal
        view
        returns (Scalar.FE)
    {
        if (i == 0) {
            return Scalar.one();
        }
        Scalar.FE term = domain_gen.pow(domain_size - i);
        Scalar.FE acc = x.sub(term);
        for (uint256 _j = 0; _j < i - 1; _j++) {
            term = term.mul(domain_gen);
            acc = acc.mul(x.sub(term));
        }
        return acc;
    }
}
