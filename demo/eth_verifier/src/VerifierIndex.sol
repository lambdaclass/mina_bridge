// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./BN254.sol";
import {URS} from "./Commitment.sol";

struct VerifierIndex {
    URS urs;
    uint public_len;
    uint domain_size;
    uint max_poly_size;
    BN254.G1 blinding_commitment;
}
