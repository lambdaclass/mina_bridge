// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Fields.sol";
import "./BN254.sol";
import {VerifierIndex} from "./VerifierIndex.sol";
import {PolyComm, polycomm_msm, mask_custom} from "./Commitment.sol";

// import "forge-std/console.sol";
import {console} from "forge-std/Test.sol";

using {BN254.neg} for BN254.G1Point;
using {Scalar.neg} for Scalar.FE;

library Kimchi {
    struct Proof {
        uint256 data;
    }

    function deserializeOpeningProof(
        uint8[69] calldata serialized_proof
    ) public view returns (ProverProof memory proof) {
        uint256 i = 0;
        uint8 firstbyte = serialized_proof[i];
        // first byte is 0x92, indicating this is a map with 2 elements
        require(firstbyte == 0x92, "first byte is not 0x92");

        // read lenght of the data
        i += 1;
        require(serialized_proof[i] == 0xC4, "second byte is not 0xC4");

        // next byte is the length of the data in one byte
        i += 1;
        require(serialized_proof[i] == 0x20, "size of element is not 32 bytes");

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
        require(serialized_proof[i] == 0xC4, "second byte is not 0xC4");

        // next byte is the length of the data in one byte
        i += 1;
        require(serialized_proof[i] == 0x20, "size of element is not 32 bytes");

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
        // evals

        // opening proof
        BN254.G1Point opening_proof_quotient;
        uint256 opening_proof_blinding;
    }

    struct Evals {
        Base.FE zeta;
        Base.FE zeta_omega;
    }

    /*
    function deserializeEvals(
        uint8[71] calldata serialized_evals
    ) public view returns (Evals memory evals) {}
    */
}

contract KimchiVerifier {
    VerifierIndex verifier_index;

    // 1) deserialize
    // 2) staticcall to precompile of pairing check

    function verify(
        uint256[] memory serializedProof
    ) public view returns (bool) {
        bool success;

        /* NOTE: this is an example of the use of the precompile
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
        */

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
        uint256 chunk_size = verifier_index.domain_size <
            verifier_index.max_poly_size
            ? 1
            : verifier_index.domain_size / verifier_index.max_poly_size;

        if (public_inputs.length != verifier_index.public_len) {
            revert IncorrectPublicInputLength();
        }
        PolyComm[] memory lgr_comm = verifier_index.urs.lagrange_bases[
            verifier_index.domain_size
        ];
        PolyComm[] memory comm = new PolyComm[](verifier_index.public_len);
        // INFO: can use unchecked on for loops to save gas
        for (uint256 i = 0; i < verifier_index.public_len; i++) {
            comm[i] = lgr_comm[i];
        }
        PolyComm memory public_comm;
        if (public_inputs.length == 0) {
            BN254.G1Point[] memory blindings = new BN254.G1Point[](chunk_size);
            for (uint256 i = 0; i < chunk_size; i++) {
                blindings[i] = verifier_index.blinding_commitment;
            }
            public_comm = PolyComm(blindings);
        } else {
            Scalar.FE[] memory elm = new Scalar.FE[](public_inputs.length);
            for (uint i = 0; i < elm.length; i++) {
                elm[i] = public_inputs[i].neg();
            }
            PolyComm memory public_comm_tmp = polycomm_msm(comm, elm);
            Scalar.FE[] memory blinders = new Scalar.FE[](
                public_comm_tmp.unshifted.length
            );
            for (uint i = 0; i < public_comm_tmp.unshifted.length; i++) {
                blinders[i] = Scalar.FE.wrap(1);
            }
            public_comm = mask_custom(
                verifier_index.urs,
                public_comm_tmp,
                blinders
            ).commitment;
        }
    }

    /* TODO WIP
    function deserialize_proof(
        uint256[] calldata public_inputs,
        uint256[] calldata serialized_proof
    ) returns (Proof memory) {}
    */

    /// @notice This is used exclusively in `test_PartialVerify()`.
    function set_verifier_index_for_testing() public {
        verifier_index.max_poly_size = 1;
    }
}
