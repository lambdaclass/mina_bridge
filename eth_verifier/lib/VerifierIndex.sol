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
    // the number of randomized rows to achieve zero knowledge
    uint64 zk_rows;
    URS urs;
    // domain
    uint256 domain_size;
    Scalar.FE domain_gen;
    /// The mapping between powers of alpha and constraints
    Alphas powers_of_alpha;
    // wire shift coordinates
    Scalar.FE[7] shift;  // TODO: use Consants.PERMUTS
    /// domain offset for zero-knowledge
    Scalar.FE w;
}

function verifier_digest(VerifierIndex storage index) returns (Base.FE) {
    // FIXME: todo!
    return Base.from(42);
}

/// @notice Defines a domain over which finite field (I)FFTs can be performed. Works
/// @notice only for fields that have a large multiplicative subgroup of size that is
/// @notice a power-of-2.
struct Domain {
    // Multiplicative generator of the finite field.
    Scalar.FE generator_inv;
    // Inverse of the generator of the subgroup.
    Scalar.FE group_gen_inv;
    // A generator of the subgroup.
    Scalar.FE group_gen;
    // Inverse of the size in the field.
    Scalar.FE size_inv;
    // Size of the domain as a field element.
    Scalar.FE size_as_field_element;
    // `log_2(self.size)`.
    uint32 log_size_of_group;
    // The size of the domain.
    uint64 size;
}
