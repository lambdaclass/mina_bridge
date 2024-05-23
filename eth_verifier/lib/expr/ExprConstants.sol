// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

// @notice constants required to evaluate an expression.
struct ExprConstants {
    uint256 alpha;
    uint256 beta;
    uint256 gamma;
    uint256 joint_combiner;
    uint256 endo_coefficient;
    // INFO: The keccak sponge doesn't use an MDS, so this shouldn't ever execute
    // They implement the keccak sponge with a "dummy" (unused) MDS.
    //uint256[] mds; // the MDS matrix in row major
    //uint256 mds_cols;
    uint256 zk_rows;
}
