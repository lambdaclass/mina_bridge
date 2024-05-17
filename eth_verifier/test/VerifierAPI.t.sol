// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Verifier.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes linearization_literals_serialized;
    bytes public_input_serialized;

    KimchiVerifier global_verifier;

    function setUp() public {
        // read serialized data from files
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        // setup verifier contract
        global_verifier = new KimchiVerifier();

        global_verifier.setup();

        global_verifier.store_verifier_index(verifier_index_serialized);
        global_verifier.store_linearization(linearization_serialized);
        global_verifier.store_literal_tokens(linearization_literals_serialized);
        global_verifier.store_prover_proof(prover_proof_serialized);
        global_verifier.store_public_input(public_input_serialized);

        global_verifier.partial_verify_and_store();
    }

    function test_deploy() public {
        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup();
    }

    function test_deserialize() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);
    }

    function test_deserialize_and_full_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);

        bool success = verifier.full_verify();
        require(success, "Verification failed!");
    }

    function test_deserialize_and_full_verify_existing_verifier() public {
        global_verifier.store_literal_tokens(linearization_literals_serialized);
        global_verifier.store_prover_proof(prover_proof_serialized);
        global_verifier.store_public_input(public_input_serialized);

        bool success = global_verifier.full_verify();
        require(success, "Verification failed!");
    }

    function test_partial_verify_and_store() public {
        global_verifier.partial_verify_and_store();
    }

    function test_final_verify() public {
        global_verifier.final_verify_and_store();
        bool success = global_verifier.is_last_proof_valid();
        require(success, "Verification failed!");
    }

    function test_multiple_setups_and_verifications() public {
        uint256 num_circuit_updates = 10;
        uint256 num_verifications_per_update = 100;
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        for (uint256 i = 0; i < num_circuit_updates; i++) {
            verifier.store_verifier_index(verifier_index_serialized);
            verifier.store_linearization(linearization_serialized);

            for (uint256 j = 0; j < num_verifications_per_update; j++) {
                verifier.store_literal_tokens(linearization_literals_serialized);
                verifier.store_prover_proof(prover_proof_serialized);
                verifier.store_public_input(public_input_serialized);

                bool success = verifier.full_verify();
                require(success, "Verification failed!");
            }
        }
    }
}
