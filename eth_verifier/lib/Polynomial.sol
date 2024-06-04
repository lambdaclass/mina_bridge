// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Scalar} from "./bn254/Fields.sol";

library Polynomial {
    // @notice evaluates the polynomial
    // @notice (x - w^{n - i}) * (x - w^{n - i + 1}) * ... * (x - w^{n - 1})

    function eval_vanishes_on_last_n_rows(uint256 domain_gen, uint256 domain_size, uint256 i, uint256 x)
        internal
        view
        returns (uint256)
    {
        if (i == 0) {
            return 1;
        }
        uint256 term = Scalar.pow(domain_gen, domain_size - i);
        uint256 acc = Scalar.sub(x, term);
        for (uint256 _j = 0; _j < i - 1; _j++) {
            term = Scalar.mul(term, domain_gen);
            acc = Scalar.mul(acc, Scalar.sub(x, term));
        }
        return acc;
    }
}
