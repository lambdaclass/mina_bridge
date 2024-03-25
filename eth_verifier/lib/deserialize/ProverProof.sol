// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Proof.sol";

function deser_proof_evaluations(
    bytes memory,
    NewProofEvaluations storage evals
) {
    assembly {
        let addr := 0xa0 // memory starts at 0x80,
                         // first 32 bytes is the length of the bytes array.
        let slot := evals.slot

        // the first 32 bytes correspond to the optional field flags:
        let optional_field_flags := mload(addr)
        addr := add(addr, 0x20)

        // the non-optional evaluations are:
        // - w[15]
        // - z
        // - s[6]
        // - coefficients[15]
        // - generic_selector
        // - poseidon_selector
        // - complete_add_selector
        // - mul_selector
        // - emul_selector
        // - endomul_scalar_selector
        // totalling 43 evaluations, so 86 scalars:
        for { let i := 0 } lt(i, 86) { i := add(i, 1) } {
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }

        // then we have optional evaluations. We know which are set and which aren't
        // thanks to the flags.
        // the optional evaluations are:
        // - range_check0_selector
        // - range_check1_selector
        // - foreign_field_add_selector
        // - foreign_field_mul_selector
        // - xor_selector
        // - rot_selector
        // - lookup_aggregation
        // - lookup_table
        // - lookup_sorted[5]
        // - runtime_lookup_table
        // - runtime_lookup_table_selector
        // - xor_lookup_selector
        // - lookup_gate_lookup_selector
        // - range_check_lookup_selector
        // - foreign_field_mul_lookup_selector
        // totalling 19 evaluations. In this case we'll index evaluations, not scalars:
        for { let i := 0 } lt(i, 19) { i := add(i, 1) } {
            let is_some := and(1, shr(optional_field_flags, i))
            switch is_some
            case 1 { // true
                // zeta:
                sstore(slot, mload(addr))
                addr := add(addr, 0x20)
                slot := add(slot, 1)
                // zeta_omega:
                sstore(slot, mload(addr))
                addr := add(addr, 0x20)
                slot := add(slot, 1)
            }
            default { // false
                addr := add(addr, 0x40)
                slot := add(slot, 2)
            }
        }
    }
}
