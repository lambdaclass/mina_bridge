// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";
import "./Utils.sol";

library Polynomial {
    using {Scalar.add, Scalar.mul, Scalar.sub, Scalar.pow} for Scalar.FE;

    struct Dense {
        Scalar.FE[] coeffs;
    }

    function evaluate(Dense memory self, Scalar.FE x) external pure returns (Scalar.FE result) {
        result = Scalar.zero();
        for (uint i = 0; i < self.coeffs.length; i++) {
            result = result.mul(x).add(self.coeffs[i]);
        }
    }

    function build_and_eval(Scalar.FE[] memory coeffs, Scalar.FE x) external pure returns (Scalar.FE result) {
        result = Scalar.zero();
        for (uint i = 0; i < coeffs.length; i++) {
            result = result.mul(x).add(coeffs[i]);
        }
    }

    function constant_poly(Scalar.FE coeff) public pure returns (Dense memory) {
        Scalar.FE[] memory coeffs = new Scalar.FE[](1);
        coeffs[0] = coeff;
        return Dense(coeffs);
    }

    function sub(Dense memory self, Dense memory other) public view returns (Dense memory) {
        uint n = Utils.max(self.coeffs.length, other.coeffs.length);
        Scalar.FE[] memory coeffs_self_sub_other = new Scalar.FE[](n);
        for (uint i = 0; i < n; i++) {
            coeffs_self_sub_other[i] = self.coeffs[i].sub(other.coeffs[i]);
        }

        return Dense(coeffs_self_sub_other);
    }

    function mul(Dense memory self, Dense memory other) public view returns (Dense memory) {
        // evaluate both polys with FFT and 2n degree bound (degree of the result poly)
        uint count = Utils.max(self.coeffs.length, other.coeffs.length) * 2;
        Scalar.FE[] memory evals_self = Utils.fft_resized(self.coeffs, count);
        Scalar.FE[] memory evals_other = Utils.fft_resized(other.coeffs, count);
        // padding with zeros results in more evaluations of the same polys

        require(evals_self.length == evals_other.length, "poly mul evals are not of the same length");
        uint n = evals_self.length;

        // point-wise multiplication
        Scalar.FE[] memory evals_self_mul_other = new Scalar.FE[](n);
        for (uint i = 0; i < n; i++) {
            evals_self_mul_other[i] = evals_self[i].mul(evals_other[i]);
        }

        // interpolate result poly
        Scalar.FE[] memory coeffs_res = Utils.ifft(evals_self_mul_other);
        return Dense(coeffs_res);
    }

    function vanishes_on_last_n_rows(Scalar.FE domain_gen, uint domain_size, uint i) external view returns (Dense memory poly) {
        if (i == 0) {
            Scalar.FE[] memory const = new Scalar.FE[](1);
            const[0] = Scalar.from(1);
            return Dense(const);
        }

        Scalar.FE[] memory coeffs = new Scalar.FE[](2);
        coeffs[0] = Scalar.zero();
        coeffs[1] = Scalar.one();
        Dense memory x = Dense(coeffs);

        Scalar.FE term = domain_gen.pow(domain_size - i);
        Dense memory acc = sub(x, constant_poly(term));
        for (uint j = 0; j < i - 1; i++) {
            term = term.mul(domain_gen);
            acc = mul(acc, sub(x, constant_poly(term)));
        }

        return acc;
    }
}
