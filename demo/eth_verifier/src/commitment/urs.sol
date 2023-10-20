// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "../BN254.sol";
import {PolyComm} from "../Commitment.sol";

struct URS {
    BN254.G1[] g;
    BN254.G1 h;

    mapping(uint => PolyComm[]) lagrange_bases;
}
