// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Verifier.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes public_input_serialized;

    KimchiVerifier verifier;

    function setUp() public {
        // read serialized data from files
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        // setup verifier contract
        verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);

        verifier.partial_verify_and_store();
    }

    function test_deserialize() public {
        KimchiVerifier new_verifier = new KimchiVerifier();

        new_verifier.setup();

        new_verifier.store_verifier_index(verifier_index_serialized);
        new_verifier.store_linearization(linearization_serialized);
        new_verifier.store_prover_proof(prover_proof_serialized);
        new_verifier.store_public_input(public_input_serialized);
    }

    function test_deserialize_and_full_verify() public {
        KimchiVerifier new_verifier = new KimchiVerifier();

        new_verifier.setup();

        new_verifier.store_verifier_index(verifier_index_serialized);
        new_verifier.store_linearization(linearization_serialized);
        new_verifier.store_prover_proof(prover_proof_serialized);
        new_verifier.store_public_input(public_input_serialized);

        bool success = new_verifier.full_verify();
        require(success, "Verification failed!");
    }

    function test_partial_verify_and_store() public {
        verifier.partial_verify_and_store();
    }

    function test_final_verify() public {
        bool success = verifier.final_verify_stored();
        require(success, "Verification failed!");
    }
}
