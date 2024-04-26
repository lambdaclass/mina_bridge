// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../VerifierIndex.sol";

function deser_verifier_index(
    bytes memory data,
    VerifierIndexLib.VerifierIndex storage verifier_index
) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := verifier_index.slot

        // the first 32 bytes correspond to the optional field flags:
        let optional_field_flags := mload(addr)
        sstore(slot, optional_field_flags)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        // the non-optional fields are:
        // - domain_size (scalar)
        // - domain_group_gen (scalar)
        // - max_poly_size (scalar)
        // - zk_rows (scalar)
        // - public_len (scalar)
        // - sigma_comm[7] (point)
        // - coefficients_comm[15] (point)
        // - generic_comm (point)
        // - psm_comm (point)
        // - complete_add_comm (point)
        // - mul_comm (point)
        // - emul_comm (point)
        // - endomul_scalar_comm (point)
        // - shift[7] (scalar)
        // - w (scalar)
        // - endo (scalar)
        // totalling 70 field elements:
        for { let i := 0 } lt(i, 70) { i := add(i, 1) } {
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }

        // then we have optional field. We know which are set and which aren't
        // thanks to the flags.
        // the optional fields are:
        // - range_check0_comm (point)
        // - range_check1_comm (point)
        // - foreign_field_add_comm (point)
        // - foreign_field_mul_comm (point)
        // - xor_comm (point)
        // - rot_comm (point)
        // - lookup_index:
        //      - optional_field_flags
        //      - lookup_table (point, non-optional)
        //      - lookup_info[2] (scalar, non-optional)
        //      - xor (point, optional)
        //      - lookup (point, optional)
        //      - range_check (point, optional)
        //      - ffmul (point, optional)
        //      - table_ids (point, optional)
        //      - runtime_tables_selector (point, optional)

        // first we have 6 optional points:
        for { let i := 0 } lt(i, 6) { i := add(i, 1) } {
            let is_some := and(1, shr(i, optional_field_flags))
            switch is_some
            case 1 { // true
                // x:
                sstore(slot, mload(addr))
                addr := add(addr, 0x20)
                slot := add(slot, 1)
                // y:
                sstore(slot, mload(addr))
                addr := add(addr, 0x20)
                slot := add(slot, 1)
            }
            default { // false
                slot := add(slot, 2)
            }
        }

        // then we have lookup index, if it's some:
        if and(1, shr(6, optional_field_flags)) {
            // it has its own optional field flags:
            optional_field_flags := mload(addr)
            sstore(slot, optional_field_flags)
            addr := add(addr, 0x20)
            slot := add(slot, 1)

            // 1 point and 2 scalars, so 4 field elements:
            for { let i := 0 } lt(i, 4) { i := add(i, 1) } {
                sstore(slot, mload(addr))
                addr := add(addr, 0x20)
                slot := add(slot, 1)
            }

            // and 6 optional points:
            for { let i := 0 } lt(i, 6) { i := add(i, 1) } {
                let is_some := and(1, shr(i, optional_field_flags))
                switch is_some
                case 1 { // true
                    // x:
                    sstore(slot, mload(addr))
                    addr := add(addr, 0x20)
                    slot := add(slot, 1)
                    // y:
                    sstore(slot, mload(addr))
                    addr := add(addr, 0x20)
                    slot := add(slot, 1)
                }
                default { // false
                    slot := add(slot, 2)
                }
            }
        }
    }
}
