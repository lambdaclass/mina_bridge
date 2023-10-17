// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

library Kimchi {
    struct Proof {
        uint data;
    }
}

struct ProofInput {
    uint256[] serializedProof;
}

contract KimchiVerifier {
    Kimchi.Proof proof;

    // 1) deserialize
    // 2) staticcall to precompile of pairing check

    function verify(
        uint256[] memory serializedProof
    ) public view returns (bool) {
        bool success;
        assembly {
            let freeMemPointer := 0x40
            success := staticcall(
                gas(),
                0x8,
                add(freeMemPointer, 28),
                add(freeMemPointer, 0x40),
                0x00,
                0x00
            )
        }

        //require(success);
        /*
        This is a list of steps needed for verification, we need to determine which
        ones can be skipped or simplified.

        Partial verification:
            1. Check the length of evaluations insde the proof.
            2. Commit to the negated public input poly
            3. Fiat-Shamir (MAY SKIP OR VASTLY SIMPLIFY)
            4. Combined chunk polynomials evaluations
            5. Commitment to linearized polynomial f
            6. Chunked commitment of ft
            7. List poly commitments for final verification

        Final verification:
            1. Combine commitments, compute final poly commitment (MSM)
            2. Combine evals
            3. Commit divisor and eval polynomials
            4. Compute numerator commitment
            5. Compute scaled quotient
            6. Check numerator == scaled_quotient
        */
        return true;
    }
}
