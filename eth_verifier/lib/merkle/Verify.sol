// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "pasta/Fields.sol";

library MerkleVerifier {
    enum LeftOrRight {
        Left,
        Right
    }

    struct MerklePathElement {
        Pasta.Fp hash;
        LeftOrRight left_or_right;
    }

    function verify_path(
        MerklePathElement[] memory merkle_path,
        MerklePathElement memory leaf_hash
    ) internal {}
}
