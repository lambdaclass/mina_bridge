// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Verifier.sol";
import {Oracles} from "../lib/Oracles.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes linearization_literals_serialized;
    bytes proof_hash_serialized;
    bytes merkle_root_serialized;
    bytes merkle_leaf_serialized;
    bytes merkle_path_serialized;

    Proof.ProverProof proof;
    VerifierIndexLib.VerifierIndex verifier_index;
    uint256 proof_hash;
    BN254.G1Point public_comm;

    error VerificationFailed();

    KimchiVerifier global_verifier;

    function setUp() public {
        // read serialized data from files
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        proof_hash_serialized = vm.readFileBinary("public_input.bin");
        merkle_root_serialized = vm.readFileBinary("merkle_root.bin");
        merkle_leaf_serialized = vm.readFileBinary("merkle_leaf.bin");
        merkle_path_serialized = vm.readFileBinary("merkle_path.bin");

        deser_prover_proof(prover_proof_serialized, proof);
        deser_verifier_index(verifier_index_serialized, verifier_index);
        proof_hash = deser_proof_hash(proof_hash_serialized);
        public_comm = BN254.scalarMul(BN254.G1Point(1, 2), 42);

        // setup verifier contract
        global_verifier = new KimchiVerifier();

        global_verifier.setup();

        global_verifier.store_verifier_index(verifier_index_serialized);
        global_verifier.store_linearization(linearization_serialized);
        global_verifier.store_literal_tokens(linearization_literals_serialized);
        global_verifier.store_prover_proof(prover_proof_serialized);
        global_verifier.store_proof_hash(proof_hash_serialized);
        global_verifier.store_potential_merkle_root(merkle_root_serialized);

        global_verifier.partial_verify_and_store();
        global_verifier.final_verify_and_store();
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
        verifier.store_proof_hash(proof_hash_serialized);
        verifier.store_potential_merkle_root(merkle_root_serialized);
    }

    function test_deserialize_and_full_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_proof_hash(proof_hash_serialized);
        verifier.store_potential_merkle_root(merkle_root_serialized);

        bool success = verifier.full_verify();
        if (!success) {
            revert VerificationFailed();
        }
    }

    function test_deserialize_and_full_verify_existing_verifier() public {
        global_verifier.store_literal_tokens(linearization_literals_serialized);
        global_verifier.store_prover_proof(prover_proof_serialized);
        global_verifier.store_proof_hash(proof_hash_serialized);
        global_verifier.store_potential_merkle_root(merkle_root_serialized);

        bool success = global_verifier.full_verify();
        if (!success) {
            revert VerificationFailed();
        }
    }

    function test_partial_verify_and_store() public {
        global_verifier.partial_verify_and_store();
    }

    function test_final_verify() public {
        global_verifier.final_verify_and_store();
        bool success = global_verifier.is_last_proof_valid();
        if (!success) {
            revert VerificationFailed();
        }
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
                verifier.store_proof_hash(proof_hash_serialized);

                bool success = verifier.full_verify();
                if (!success) {
                    revert VerificationFailed();
                }
            }
        }
    }

    function test_merkle_verify() public {
        bool success = global_verifier.verify_account_inclusion(
            bytes32(merkle_leaf_serialized),
            merkle_path_serialized
        );
        if (!success) {
            revert VerificationFailed();
        }
    }

    /*
    function test_oracles_fiat_shamir() public {
        Oracles.Result memory oracles_res = Oracles.fiat_shamir(proof, verifier_index, 
            public_comm, public_input, true);
    }
    */
}
