// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./BN254.sol";

struct URS {
    BN254.G1[] g;
    BN254.G1 h;
    mapping(uint => PolyComm[]) lagrange_bases;
}

struct PolyComm {
    BN254.G1[] unshifted;
    //BN254G1 shifted;
    // WARN: The previous field is optional but in Solidity we can't have that.
    // for our test circuit (circuit_gen/) it's not necessary
}
