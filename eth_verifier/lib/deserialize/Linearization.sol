// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../expr/Expr.sol";

import "forge-std/console.sol";

function deser_linearization(
    bytes memory data,
    NewLinearization storage linearization
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
