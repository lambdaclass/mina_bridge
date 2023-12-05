// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

// @notice constants required to evaluate an expression.
struct ExprConstants {
    Scalar.FE alpha;
    Scalar.FE beta;
    Scalar.FE gamma;
    Scalar.FE joint_combiner;
    Scalar.FE endo_coefficient;
    Scalar.FE[] mds; // the MDS matrix in row/col major // FIXME: determine order
    uint zk_rows;
}
