// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Scalar, Base} from "./Fields.sol";
import {VerifierIndex} from "./VerifierIndex.sol";
import {PolyComm} from "./Commitment.sol";

library Kimchi {
    struct Proof {
        uint256 data;
    }
}

struct ProofInput {
    uint256[] serializedProof;
}

contract KimchiVerifier {
    VerifierIndex verifier_index;

    // 1) deserialize
    // 2) staticcall to precompile of pairing check

    function verify(uint256[] memory serializedProof)
        public
        view
        returns (bool)
    {
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

    /*
        Partial verification:
            1. Check the length of evaluations insde the proof. SKIPPED
            2. Commit to the negated public input poly
            3. Fiat-Shamir (MAY SKIP OR VASTLY SIMPLIFY)
            4. Combined chunk polynomials evaluations
            5. Commitment to linearized polynomial f
            6. Chunked commitment of ft
            7. List poly commitments for final verification
    */
    error IncorrectPublicInputLength();

    function partial_verify(Scalar.FE[] memory public_inputs) public view {
        if (public_inputs.length != verifier_index.public_len) {
            revert IncorrectPublicInputLength();
        }
        PolyComm[] memory lgr_comm = verifier_index.urs.lagrange_bases[
            verifier_index.domain_size
        ];
        PolyComm[] memory comm = new PolyComm[](verifier_index.public_len);
        // INFO: can use unchecked on this loop to save gas
        for (uint256 i = 0; i < verifier_index.public_len; i++) {
            comm[i] = lgr_comm[i];
        }
        PolyComm memory public_comm;
        if (public_inputs.length == 0) {
            PolyComm[] blindings = new PolyComm[](chunk_size);
            // INFO: can use unchecked on this loop to save gas
            for (uint i = 0; i < chunk_size; i++) {
                blindings[i] = 
            }
            public_comm = new PolyComm(blindings);
        }

        /*
        let public_comm = {
            if public_input.len() != verifier_index.public {
                return Err(VerifyError::IncorrectPubicInputLength(
                    verifier_index.public,
                ));
            }
            let lgr_comm = verifier_index
                .srs()
                .get_lagrange_basis(verifier_index.domain.size())
                .expect("pre-computed committed lagrange bases not found");
            let com: Vec<_> = lgr_comm.iter().take(verifier_index.public).collect();
            if public_input.is_empty() {
                PolyComm::new(
                    vec![verifier_index.srs().blinding_commitment(); chunk_size],
                    None,
                )
            } else {
                let elm: Vec<_> = public_input.iter().map(|s| -*s).collect();
                let public_comm = PolyComm::<G>::multi_scalar_mul(&com, &elm);
                verifier_index
                    .srs()
                    .mask_custom(
                        public_comm.clone(),
                        &public_comm.map(|_| G::ScalarField::one()),
                    )
                    .unwrap()
                    .commitment
            }
        };
        */
    }

    /* TODO WIP
    function deserialize_proof(
        uint256[] calldata public_inputs,
        uint256[] calldata serialized_proof
    ) returns (Proof memory) {}
    */
}
