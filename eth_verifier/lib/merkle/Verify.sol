// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "pasta/Fields.sol";
import "poseidon/Sponge.sol";

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
        MerklePathElement memory leaf_hash,
        Poseidon poseidon
    ) internal view returns (Pasta.Fp) {
        Pasta.Fp acc = leaf_hash.hash;

        for (uint256 i = 0; i < merkle_path.length; i++) {
            Poseidon.Sponge memory sponge = poseidon.new_sponge();
            poseidon.absorb(sponge, get_salt(i));

            if (merkle_path[i].left_or_right == LeftOrRight.Left) {
                poseidon.absorb(sponge, acc);
                poseidon.absorb(sponge, merkle_path[i].hash);
            } else {
                poseidon.absorb(sponge, merkle_path[i].hash);
                poseidon.absorb(sponge, acc);
            }
            (sponge, acc) = poseidon.squeeze(sponge);
        }

        return acc;
    }

    function get_salt(uint256 i) private pure returns (Pasta.Fp) {
        return Pasta.Fp.wrap(i); // FIXME: placeholder
    }
}
