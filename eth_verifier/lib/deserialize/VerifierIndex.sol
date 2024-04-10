// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Commitment.sol";

import "forge-std/console.sol";

// WARN: using the entire `full_urs` may not be necessary, we would only have to deserialize the
// first two points (in the final verification step, we need the `full_urs` for commitment a
// evaluation polynomial, which seems to be always of degree 1).
function deser_pairing_urs(bytes memory data, URS storage urs) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := urs.slot

        // Now store every G element
        for { let i := 0 } lt(i, 3) { i := add(i, 1) } {
            // x:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
            // y:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }

        // Now store H
        // x:
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)
        // y:
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)
    }
}
