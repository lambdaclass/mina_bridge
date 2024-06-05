// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../pasta/Fields.sol";
import "../merkle/Verify.sol";
import {Test, console2} from "forge-std/Test.sol";

function deser_merkle_path(
    bytes memory data
) pure returns (MerkleVerifier.PathElement[] memory merkle_path) {
    uint256 data_word_length = data.length / 32;
    merkle_path = new MerkleVerifier.PathElement[](data_word_length / 2);

    for (uint256 i = 0; i < merkle_path.length; i++) {
        uint256 hash = 0;
        uint256 left_or_right = 0;
        assembly ("memory-safe") {
            let data_addr := add(data, 0x20)
            data_addr := add(data_addr, mul(i, 0x40))
            hash := mload(data_addr)
            left_or_right := mload(add(data_addr, 0x20))
        }
        merkle_path[i].hash = Pasta.from(hash);
        merkle_path[i].left_or_right = MerkleVerifier.LeftOrRight(left_or_right);
    }
}
