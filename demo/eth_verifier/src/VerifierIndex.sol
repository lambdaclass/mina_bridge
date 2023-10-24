// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./primitives/BN254.sol";
import "./Commitment.sol";

struct VerifierIndex {
    URS urs;
    uint public_len;
    uint domain_size;
    uint max_poly_size;
    BN254.G1Point blinding_commitment;
}
