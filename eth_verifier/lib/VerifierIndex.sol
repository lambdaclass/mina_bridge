// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./bn254/BN254.sol";
import {URS} from "./Commitment.sol";
import "./bn254/Fields.sol";
import "./Alphas.sol";
import "./Evaluations.sol";

struct VerifierIndex {
    // number of public inputs
    uint256 public_len;
    // maximal size of polynomial section
    uint256 max_poly_size;
    URS urs;
    // domain
    uint256 domain_size;
    Scalar.FE domain_gen;
    /// The mapping between powers of alpha and constraints
    Alphas powers_of_alpha;
    // wire shift coordinates
    Scalar.FE[7] shift;  // TODO: use Consants.PERMUTS
}

function verifier_digest(VerifierIndex storage index) returns (Base.FE) {
    // FIXME: todo!
    return Base.from(42);
}
