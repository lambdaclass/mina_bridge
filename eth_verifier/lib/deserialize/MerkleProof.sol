// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import "../merkle/Verify.sol";

function deser_merkle_path(
    bytes memory data
) pure returns (MerkleVerifier.PathElement[] memory merkle_path) {
    uint256 data_word_length = data.length / 32;
    merkle_path = new MerkleVerifier.PathElement[](data_word_length / 2);

    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let data_addr := add(data, 0x20)

        // address of merkle path's first element
        let merkle_path_addr := add(merkle_path, 0x20)

        // fill merkle path with data
        for { let i := 0 } lt(i, data_word_length) { i := add(i, 1) } {
            mstore(merkle_path_addr, mload(data_addr))
            data_addr := add(data_addr, 0x20)
            merkle_path_addr := add(merkle_path_addr, 0x20)
        }
    }
}
