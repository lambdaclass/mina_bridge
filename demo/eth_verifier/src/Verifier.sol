// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Scalar, Base} from "./Fields.sol";
import {BN254} from "../src/BN254.sol";

import "forge-std/console.sol";

library Kimchi {
    struct Proof {
        uint data;
    }

    function deserializeProof(
        uint8[69] calldata serialized_proof
    ) public view returns (ProverProof memory proof) {
        uint256 i = 0;
        uint8 firstbyte = serialized_proof[i];
        // first byte is 0x92, indicating this is a map with 2 elements
        if (firstbyte != 0x92) {
            // TODO: return error
            proof.opening_proof_quotient = BN254.P1();
            return proof;
        }

        // read lenght of the data
        i += 1;
        if (serialized_proof[i] != 0xC4) {
            // TODO! not implemented!
            proof.opening_proof_quotient = BN254.P1();
            return proof;
        }

        // next byte is the length of the data in one byte
        i += 1;
        if (serialized_proof[i] != 0x20) {
            // length of data is not 32 bytes
            // TODO! not implemented!
            proof.opening_proof_quotient = BN254.P1();
            return proof;
        }

        // read data
        i += 1;
        uint256 data_quotient = 0;
        for (uint256 j = 0; j < 32; j++) {
            data_quotient =
                data_quotient +
                uint256(serialized_proof[j + i]) *
                (2 ** (8 * (31 - j)));
        }

        proof.opening_proof_quotient = BN254.g1Deserialize(
            bytes32(data_quotient)
        );

        // read blinding
        i += 32;
        // read length of the data
        if (serialized_proof[i] != 0xC4) {
            // TODO! not implemented!
            proof.opening_proof_quotient = BN254.P1();
            return proof;
        }

        // next byte is the length of the data in one byte
        i += 1;
        if (serialized_proof[i] != 0x20) {
            // length of data is not 32 bytes
            // TODO! not implemented!
            proof.opening_proof_quotient = BN254.P1();
            return proof;
        }

        // read data
        i += 1;
        uint256 data_blinding = 0;
        for (uint256 j = 0; j < 32; j++) {
            data_blinding =
                data_blinding +
                uint256(serialized_proof[j + i]) *
                (2 ** (8 * (31 - j)));
        }

        proof.opening_proof_blinding = data_blinding;
        return proof;
    }

    struct ProofInput {
        uint256[] serializedProof;
    }

    struct ProverProof {
        BN254.G1 opening_proof_quotient;
        uint256 opening_proof_blinding;
    }
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
    function partial_verify(Scalar.FE[] memory public_inputs) public view {
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
