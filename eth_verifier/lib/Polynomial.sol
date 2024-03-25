// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";
import "./Utils.sol";

library Polynomial {
    using {Scalar.add, Scalar.mul, Scalar.sub, Scalar.pow, Scalar.neg} for Scalar.FE;

    struct Dense {
        Scalar.FE[] coeffs;
    }

    function is_zero(Dense memory self) public pure returns (bool) {
        bool all_zero = true;
        for (uint256 i = 0; i < self.coeffs.length; i++) {
            if (Scalar.FE.unwrap(self.coeffs[i]) != 0) {
                all_zero = false;
                break;
            }
        }
        return all_zero; // if coeffs is empty, this will return true too.
    }

    // @notice evaluates via Horner's method.
    function evaluate(Dense memory self, Scalar.FE x) external pure returns (Scalar.FE result) {
        result = Scalar.zero();
        for (uint256 i = self.coeffs.length; i > 0; i--) {
            result = result.mul(x).add(self.coeffs[i - 1]);
        }
    }

    // @notice evaluates via Horner's method.
    function build_and_eval(Scalar.FE[] memory coeffs, Scalar.FE x) external pure returns (Scalar.FE result) {
        result = coeffs[coeffs.length - 1];
        if (coeffs.length == 1) {
            return result;
        }
        uint256 i = coeffs.length - 2;
        while (i > 0) {
            result = result.mul(x).add(coeffs[i]);
            --i;
        }
    }

    function constant_poly(Scalar.FE coeff) public pure returns (Dense memory) {
        Scalar.FE[] memory coeffs = new Scalar.FE[](1);
        coeffs[0] = coeff;
        return Dense(coeffs);
    }

    function binomial(Scalar.FE first_coeff, Scalar.FE second_coeff) public pure returns (Dense memory) {
        Scalar.FE[] memory coeffs = new Scalar.FE[](2);
        coeffs[0] = first_coeff;
        coeffs[1] = second_coeff;
        return Dense(coeffs);
    }

    function sub(Dense memory self, Dense memory other) public pure returns (Dense memory) {
        uint256 n = Utils.min(self.coeffs.length, other.coeffs.length);
        Scalar.FE[] memory coeffs_self_sub_other = new Scalar.FE[](n);
        for (uint256 i = 0; i < n; i++) {
            coeffs_self_sub_other[i] = self.coeffs[i].sub(other.coeffs[i]);
        }

        return Dense(coeffs_self_sub_other);
    }

    function mul(Dense memory self, Dense memory other) public pure returns (Dense memory) {
        // evaluate both polys with FFT and 2n degree bound (degree of the result poly)
        uint256 count = Utils.max(self.coeffs.length, other.coeffs.length) * 2;
        Scalar.FE[] memory evals_self = Utils.fft_resized(self.coeffs, count);
        Scalar.FE[] memory evals_other = Utils.fft_resized(other.coeffs, count);
        // padding with zeros results in more evaluations of the same polys

        require(evals_self.length == evals_other.length, "poly mul evals are not of the same length");
        uint256 n = evals_self.length;

        // point-wise multiplication
        Scalar.FE[] memory evals_self_mul_other = new Scalar.FE[](n);
        for (uint256 i = 0; i < n; i++) {
            evals_self_mul_other[i] = evals_self[i].mul(evals_other[i]);
        }

        // interpolate result poly
        Scalar.FE[] memory coeffs_res = Utils.ifft(evals_self_mul_other);
        return Dense(coeffs_res);
    }

    // @notice evaluates the polynomial
    // @notice (x - w^{n - i}) * (x - w^{n - i + 1}) * ... * (x - w^{n - 1})
    function eval_vanishes_on_last_n_rows(Scalar.FE domain_gen, uint256 domain_size, uint256 i, Scalar.FE x)
        public
        pure
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

    /// @notice the polynomial that evaluates to `0` at the evaluation points.
    function divisor_polynomial(Scalar.FE[] memory elm) public pure returns (Dense memory result) {
        result = binomial(elm[0].neg(), Scalar.one());
        for (uint256 i = 1; i < elm.length; i++) {
            result = mul(result, binomial(elm[i].neg(), Scalar.one()));
        }
    }
}
