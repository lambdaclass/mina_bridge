// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

function deser_proof_hash(bytes memory data) pure returns (uint256 proof_hash) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)

        // Store public input
        proof_hash := mload(addr)
    }
}
