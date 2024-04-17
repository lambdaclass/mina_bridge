// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

function deser_public_inputs(bytes memory data, Scalar.FE[222] storage public_input) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := public_input.slot

        for { let i := 0 } lt(i, 222) { i := add(i, 1) } {
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }
    }
}
