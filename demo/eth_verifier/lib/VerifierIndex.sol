// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./BN254.sol";
import {URS} from "./Commitment.sol";
import "./Fields.sol";
import "../src/Alphas.sol";
import "../src/Evaluations.sol";

struct VerifierIndex {
    uint256 public_len;
    uint256 max_poly_size;
    URS urs;
    uint256 domain_size;
    Scalar.FE domain_gen;
    Alphas powers_of_alpha;
}
