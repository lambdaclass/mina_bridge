// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Verifier.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes public_input_serialized;

    KimchiVerifier global_verifier;

    function setUp() public {
        // read serialized data from files
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        // setup verifier contract
        global_verifier = new KimchiVerifier();

        global_verifier.setup();

        global_verifier.store_verifier_index(verifier_index_serialized);
        global_verifier.store_linearization(linearization_serialized);
        global_verifier.store_prover_proof(prover_proof_serialized);
        global_verifier.store_public_input(public_input_serialized);

        global_verifier.partial_verify_and_store();
    }

    function test_deserialize() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);
    }

    function test_deserialize_and_full_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);

        bool success = verifier.full_verify();
        require(success, "Verification failed!");
    }

    function test_partial_verify_and_store() public {
        global_verifier.partial_verify_and_store();
    }

    function test_final_verify() public {
        bool success = global_verifier.final_verify_stored();
        require(success, "Verification failed!");
    }
}
