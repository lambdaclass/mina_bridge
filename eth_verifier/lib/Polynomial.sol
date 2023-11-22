// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";

library Polynomial {
    using {Scalar.add, Scalar.mul} for Scalar.FE;

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
}
