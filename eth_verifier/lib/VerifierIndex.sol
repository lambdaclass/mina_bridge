// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./bn254/BN254.sol";
import {URS} from "./Commitment.sol";
import "./bn254/Fields.sol";
import "./Alphas.sol";
import "./Evaluations.sol";
import "./expr/Expr.sol";
import "./Proof.sol";

struct VerifierIndex {
    // number of public inputs
    uint256 public_len;
    // maximal size of polynomial section
    uint256 max_poly_size;
    // the number of randomized rows to achieve zero knowledge
    uint64 zk_rows;
    // domain
    uint64 domain_size;
    Scalar.FE domain_gen;
    /// The mapping between powers of alpha and constraints
    Alphas powers_of_alpha;
    // wire shift coordinates
    Scalar.FE[7] shift; // TODO: use Consants.PERMUTS
    /// domain offset for zero-knowledge
    Scalar.FE w;
    Linearization linearization;
    // polynomial commitments

    // permutation commitment array
    PolyComm[7] sigma_comm; // TODO: use Constants.PERMUTS
    // coefficient commitment array
    PolyComm[15] coefficients_comm; // TODO: use Constants.COLUMNS
}

function verifier_digest(VerifierIndex storage index) returns (Base.FE) {
    // FIXME: todo!
    return Base.from(42);
}

error UnimplementedVariant(ColumnVariant variant);

function get_column(
    VerifierIndex storage verifier_index,
    ProverProof storage proof,
    Column memory column
) view returns (PolyComm memory) {
    ColumnVariant colv = column.variant;
    if (colv == ColumnVariant.Witness) {
        uint256 i = abi.decode(column.data, (uint256));
        return proof.commitments.w_comm[i];
    } else if (colv == ColumnVariant.Coefficient) {
        uint256 i = abi.decode(column.data, (uint256));
        return verifier_index.coefficients_comm[i];
    } else if (colv == ColumnVariant.Permutation) {
        uint256 i = abi.decode(column.data, (uint256));
        return verifier_index.sigma_comm[i];
    } else if (colv == ColumnVariant.Z) {
        uint256 i = abi.decode(column.data, (uint256));
        return proof.commitments.z_comm;
    } else {
        revert UnimplementedVariant(column.variant);
    }

    // TODO: other variants remain to be implemented.
}
