// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/deserialize/PairingProof.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/Proof.sol";
import "../lib/Constants.sol";

contract DeserializeTest is Test {
    bytes pairing_proof_bytes;
    bytes proof_evals_bytes;
    bytes proof_comms_bytes;

    NewPairingProof pairing_proof;
    NewProofEvaluations proof_evals;
    NewProverCommitments proof_comms;

    function setUp() public {
        pairing_proof_bytes = vm.readFileBinary(
            "./unit_test_data/pairing_proof.bin"
        );
        proof_evals_bytes = vm.readFileBinary(
            "./unit_test_data/proof_evals.bin"
        );
        proof_comms_bytes = vm.readFileBinary(
            "./unit_test_data/proof_comms.bin"
        );
    }

    function assertTestEval(PointEvaluations memory eval) internal {
        assertEq(Scalar.FE.unwrap(eval.zeta), 1);
        assertEq(Scalar.FE.unwrap(eval.zeta_omega), 42);
    }

    function assertEmptyEval(PointEvaluations memory eval) internal {
        assertEq(Scalar.FE.unwrap(eval.zeta), 0);
        assertEq(Scalar.FE.unwrap(eval.zeta_omega), 0);
    }

    function assertTestG1Point(BN254.G1Point memory p) internal {
        assertEq(p.x, 1);
        assertEq(p.y, 2);
    }

    function test_deser_new_pairing_proof() public {
        deser_pairing_proof(pairing_proof_bytes, pairing_proof);

        assertTestG1Point(pairing_proof.quotient);
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
        assertTestEval(proof_evals.z);
        assertTestEval(proof_evals.public_evals);
        assertTestEval(proof_evals.range_check0_selector);
        assertEmptyEval(proof_evals.range_check1_selector);
        assertTestEval(proof_evals.foreign_field_add_selector);
    }

    function test_deser_new_proof_comms() public {
        deser_proof_comms(proof_comms_bytes, proof_comms);

        // optional field flags
        assertEq(
            bitmap.unwrap(proof_comms.optional_field_flags),
            3 // 0b11
        );

        for (uint256 i = 0; i < COLUMNS; i++) {
            assertTestG1Point(proof_comms.w_comm[i]);
        }
    }
}
