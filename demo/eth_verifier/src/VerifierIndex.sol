// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./BN254.sol";
import {URS} from "./Commitment.sol";
import "./Fields.sol";

struct VerifierIndex {
    URS urs;
    uint256 public_len;
    uint256 domain_size;
    Scalar.FE domain_gen;
    uint256 max_poly_size;
}
