// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

import "forge-std/console.sol";

function deser_public_input(bytes memory data) pure returns (Scalar.FE public_input) {
    uint256 inner;
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)

        // Store public input
        inner := mload(addr)
    }
    public_input = Scalar.FE.wrap(inner);
}
