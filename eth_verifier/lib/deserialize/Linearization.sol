// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../expr/Expr.sol";

import "forge-std/console.sol";

function deser_linearization(
    bytes memory data,
    Linearization storage linearization
) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := linearization.slot

        // store total variants len
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        // We have 6 dynamic arrays to store:
        for { let _arr := 0 } lt(_arr, 6) { _arr := add(_arr, 1) } {
            // store len
            let dyn_len := mload(addr)
            sstore(slot, dyn_len)
            addr := add(addr, 0x20)

            // get address to first element of dynamic array
            let free_mem_addr := mload(0x40)
            mstore(free_mem_addr, slot)
            let next_dyn_addr := keccak256(free_mem_addr, 0x20)

            // store data
            for { let i := 0 } lt(i, dyn_len) { i := add(i, 1) } {
                sstore(next_dyn_addr, mload(addr))
                addr := add(addr, 0x20)
                next_dyn_addr := add(next_dyn_addr, 1)
            }

            slot := add(slot, 1)
        }
    }
}

// Used whenever deserializing a new proof, as most of the literal tokens will
// change for each proof.
function deser_literal_tokens(
    bytes memory data,
    Linearization storage linearization
) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := linearization.slot

        // There're 6 dynamic arrays, we want to just update the literals one
        // which is the third one. We need to skip the first two.

        // First we skip the total variants len (32 bytes)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        // Then skip two dyn arrays
        for { let _arr := 0 } lt(_arr, 2) { _arr := add(_arr, 1) } {
            let dyn_len := mload(addr)
            addr := add(addr, 0x20)
            // skip 32 * dyn_len bytes
            addr := add(addr, mul(dyn_len, 0x20))
            // skip array slot
            slot := add(slot, 1)
        }

        // Then serialize literal tokens

        // store len
        let dyn_len := mload(addr)
        sstore(slot, dyn_len)
        addr := add(addr, 0x20)

        // get address to first element of dynamic array
        let free_mem_addr := mload(0x40)
        mstore(free_mem_addr, slot)
        let next_dyn_addr := keccak256(free_mem_addr, 0x20)

        // store data
        for { let i := 0 } lt(i, dyn_len) { i := add(i, 1) } {
            sstore(next_dyn_addr, mload(addr))
            addr := add(addr, 0x20)
            next_dyn_addr := add(next_dyn_addr, 1)
        }
    }
}
