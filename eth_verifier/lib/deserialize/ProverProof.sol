// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Proof.sol";

function deser_proof_comms(
    bytes memory data,
    NewProverCommitments storage comms
) {
    assembly {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := comms.slot

        // the first 32 bytes correspond to the optional field flags:
        let optional_field_flags := mload(addr)
        sstore(slot, optional_field_flags)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        // the non-optional commitments are:
        // - w[15]
        // - z
        // - t[7]
        // totalling 23 commitments, so 46 base field elements (each one is a G1 point):
        for { let i := 0 } lt(i, 46) { i := add(i, 1) } {
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }

        // then we have optional commitments. We know which are set and which aren't
        // thanks to the flags.
        // the optional commitments are:
        // - lookup_sorted[] (dynamic)
        // - lookup_aggreg
        // - lookup_runtime
        // totalling 2 commitments + the length of `lookup_sorted`.

        if and(1, optional_field_flags) { // if the lookup comms are present
            // First we'll take care of lookup_sorted. The slot of
            // the last element of a dynamic array is the keccak hash of
            // the array slot. Also the array slot contains its length.

            // Get the last element slot by hashing the array:
            let free_mem_addr := mload(0x40)
            mstore(free_mem_addr, slot)
            let lookup_sorted_ptr := keccak256(free_mem_addr, 0x20)

            // Store the length (first encoded word is the length):
            let lookup_sorted_len := mload(addr)
            sstore(slot, lookup_sorted_len)
            addr := add(addr, 0x20)
            slot := add(slot, 1)

            // Now store every element
            for { let i := 0 } lt(i, lookup_sorted_len) { i := add(i, 1) } {
                // x:
                sstore(lookup_sorted_ptr, mload(addr))
                addr := add(addr, 0x20)
                lookup_sorted_ptr := add(lookup_sorted_ptr, 1)
                // y:
                sstore(lookup_sorted_ptr, mload(addr))
                addr := add(addr, 0x20)
                lookup_sorted_ptr := add(lookup_sorted_ptr, 1)
            }

            // Now we store lookup_aggreg:
            // x:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
            // y:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)

            // Now lookup_runtime if it's present:
            if and(1, shr(1, optional_field_flags)) {
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
    }
}

function deser_proof_evals(
    bytes memory data,
    NewProofEvaluations storage evals
) {
    assembly {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := evals.slot

        // the first 32 bytes correspond to the optional field flags:
        let optional_field_flags := mload(addr)
        sstore(slot, optional_field_flags)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

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
        // - public_evals
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
        // totalling 20 evaluations. In this case we'll index evaluations, not scalars:
        for { let i := 0 } lt(i, 20) { i := add(i, 1) } {
            let is_some := and(1, shr(i, optional_field_flags))
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
                slot := add(slot, 2)
            }
        }
    }
}

function deser_pairing_proof(
    bytes memory data,
    NewPairingProof storage pairing_proof
) {
    assembly {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := pairing_proof.slot

        sstore(slot, mload(addr))
        sstore(add(slot, 1), mload(add(addr, 0x20)))
        sstore(add(slot, 2), mload(add(addr, 0x40)))
    }
}

function deser_prover_proof(
    bytes memory data,
    NewProverProof storage prover_proof
) {
    assembly ("memory-safe") {
        // first 32 bytes is the length of the bytes array, we'll skip them.
        let addr := add(data, 0x20)
        let slot := prover_proof.slot

        /** Decode commitments **/

        // the first 32 bytes correspond to the optional field flags:
        let optional_field_flags := mload(addr)
        sstore(slot, optional_field_flags)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        // the non-optional commitments are:
        // - w[15]
        // - z
        // - t[7]
        // totalling 23 commitments, so 46 base field elements (each one is a G1 point):
        for { let i := 0 } lt(i, 46) { i := add(i, 1) } {
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
        }

        // then we have optional commitments. We know which are set and which aren't
        // thanks to the flags.
        // the optional commitments are:
        // - lookup_sorted[] (dynamic)
        // - lookup_aggreg
        // - lookup_runtime
        // totalling 2 commitments + the length of `lookup_sorted`.

        if and(1, optional_field_flags) { // if the lookup comms are present
            // First we'll take care of lookup_sorted. The slot of
            // the last element of a dynamic array is the keccak hash of
            // the array slot. Also the array slot contains its length.

            // Get the last element slot by hashing the array:
            let free_mem_addr := mload(0x40)
            mstore(free_mem_addr, slot)
            let lookup_sorted_ptr := keccak256(free_mem_addr, 0x20)

            // Store the length (first encoded word is the length):
            let lookup_sorted_len := mload(addr)
            sstore(slot, lookup_sorted_len)
            addr := add(addr, 0x20)
            slot := add(slot, 1)

            // Now store every element
            for { let i := 0 } lt(i, lookup_sorted_len) { i := add(i, 1) } {
                // x:
                sstore(lookup_sorted_ptr, mload(addr))
                addr := add(addr, 0x20)
                lookup_sorted_ptr := add(lookup_sorted_ptr, 1)
                // y:
                sstore(lookup_sorted_ptr, mload(addr))
                addr := add(addr, 0x20)
                lookup_sorted_ptr := add(lookup_sorted_ptr, 1)
            }

            // Now we store lookup_aggreg:
            // x:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)
            // y:
            sstore(slot, mload(addr))
            addr := add(addr, 0x20)
            slot := add(slot, 1)

            // Now lookup_runtime if it's present:
            switch and(1, shr(1, optional_field_flags)) 
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

        /** Decode opening **/

        // opening consists of a point and a scalar, so three uints:
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)
        sstore(slot, mload(addr))
        addr := add(addr, 0x20)
        slot := add(slot, 1)

        /** Decode evaluations: **/

        // the first 32 bytes correspond to the optional field flags:
        optional_field_flags := mload(addr)
        sstore(slot, optional_field_flags)
        addr := add(addr, 0x20)
        slot := add(slot, 1)

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
        // - public_evals
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
        // totalling 20 evaluations. In this case we'll index evaluations, not scalars:
        for { let i := 0 } lt(i, 20) { i := add(i, 1) } {
            let is_some := and(1, shr(i, optional_field_flags))
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
                slot := add(slot, 2)
            }
        }

        /** Decode ft_eval1: **/

        // ft_eval1 is just a scalar:
        sstore(slot, mload(addr))
    }
}
