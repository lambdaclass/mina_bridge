// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/deserialize/PairingProof.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/Proof.sol";

contract DeserializeTest is Test {
    bytes pairing_proof_bytes;
    bytes proof_evals_bytes;

    NewPairingProof pairing_proof;
    NewProofEvaluations proof_evals;

    function setUp() public {
        pairing_proof_bytes = vm.readFileBinary(
            "./unit_test_data/pairing_proof.bin"
        );
        proof_evals_bytes = vm.readFileBinary(
            "./unit_test_data/proof_evals.bin"
        );
    }

    function test_deser_new_pairing_proof() public {
        deser_pairing_proof(pairing_proof_bytes, pairing_proof);

        assertEq(pairing_proof.quotient.x, 1);
        assertEq(pairing_proof.quotient.y, 2);
        assertEq(Scalar.FE.unwrap(pairing_proof.blinding), 1);
    }

    function test_deser_new_proof_evals() public {
        deser_proof_evals(proof_evals_bytes, proof_evals);

        // optional field flags
        assertEq(
            bitmap.unwrap(proof_evals.optional_field_flags),
            (1 << 0) + (1 << 1) + (1 << 3)
        );

        // will only test some fields:

        // z
        assertEq(Scalar.FE.unwrap(proof_evals.z.zeta), 1);
        assertEq(Scalar.FE.unwrap(proof_evals.z.zeta_omega), 42);

        // public_evals
        assertEq(Scalar.FE.unwrap(proof_evals.public_evals.zeta), 1);
        assertEq(Scalar.FE.unwrap(proof_evals.public_evals.zeta_omega), 42);

        // range_check0_selector
        assertEq(Scalar.FE.unwrap(proof_evals.range_check0_selector.zeta), 1);
        assertEq(
            Scalar.FE.unwrap(proof_evals.range_check0_selector.zeta_omega),
            42
        );

        // range_check1_selector
        assertEq(Scalar.FE.unwrap(proof_evals.range_check1_selector.zeta), 0);
        assertEq(
            Scalar.FE.unwrap(proof_evals.range_check1_selector.zeta_omega),
            0
        );

        // foreign_field_add_selector
        assertEq(
            Scalar.FE.unwrap(proof_evals.foreign_field_add_selector.zeta),
            1
        );
        assertEq(
            Scalar.FE.unwrap(proof_evals.foreign_field_add_selector.zeta_omega),
            42
        );
    }
}
