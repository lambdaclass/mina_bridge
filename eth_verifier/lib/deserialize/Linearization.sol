// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "forge-std/console.sol";

function deser_linearization(
    bytes memory data,
    uint256[] storage linearization_variants,
    uint256[] storage linearization_mds,
    uint256[] storage linearization_literals,
    uint256[] storage linearization_pows,
    uint256[] storage linearization_loads
) {
    uint256 test_mem = 42;
    assembly {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)

        let variants_len := mload(addr)
        test_mem := variants_len
        addr := add(addr, 0x20)
        let mds_len := mload(addr)
        addr := add(addr, 0x20)
        let literals_len := mload(addr)
        addr := add(addr, 0x20)
        let pows_len := mload(addr)
        addr := add(addr, 0x20)
        let loads_len := mload(addr)
        addr := add(addr, 0x20)

        // we save the lengths for each dynamic array:
        sstore(linearization_variants.slot, variants_len)
        sstore(linearization_mds.slot, mds_len)
        sstore(linearization_literals.slot, literals_len)
        sstore(linearization_pows.slot, pows_len)
        sstore(linearization_loads.slot, loads_len)

        let free_mem_addr := mload(0x40)

        // get pointers to dynamic arrays (a pointer is just an address)
        mstore(free_mem_addr, linearization_variants.slot)
        let variants_ptr := keccak256(free_mem_addr, 0x20)

        mstore(free_mem_addr, linearization_mds.slot)
        let mds_ptr := keccak256(free_mem_addr, 0x20)

        mstore(free_mem_addr, linearization_literals.slot)
        let literals_ptr := keccak256(free_mem_addr, 0x20)

        mstore(free_mem_addr, linearization_pows.slot)
        let pows_ptr := keccak256(free_mem_addr, 0x20)

        mstore(free_mem_addr, linearization_loads.slot)
        let loads_ptr := keccak256(free_mem_addr, 0x20)

        // now store the data
        for { let i := 0 } lt(i, variants_len) { i := add(i, 1) } {
            sstore(variants_ptr, mload(addr))
            addr := add(addr, 0x20)
            variants_ptr := add(variants_ptr, 1)
        }
        for { let i := 0 } lt(i, mds_len) { i := add(i, 1) } {
            sstore(mds_ptr, mload(addr))
            addr := add(addr, 0x20)
            mds_ptr := add(mds_ptr, 1)
        }
        for { let i := 0 } lt(i, literals_len) { i := add(i, 1) } {
            sstore(literals_ptr, mload(addr))
            addr := add(addr, 0x20)
            literals_ptr := add(literals_ptr, 1)
        }
        for { let i := 0 } lt(i, pows_len) { i := add(i, 1) } {
            sstore(pows_ptr, mload(addr))
            addr := add(addr, 0x20)
            pows_ptr := add(pows_ptr, 1)
        }
        for { let i := 0 } lt(i, loads_len) { i := add(i, 1) } {
            sstore(loads_ptr, mload(addr))
            addr := add(addr, 0x20)
            loads_ptr := add(loads_ptr, 1)
        }
    }
}
