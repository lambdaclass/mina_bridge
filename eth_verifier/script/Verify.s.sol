// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    bytes linearization_literals_serialized;
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes proof_hash_serialized;
    bytes merkle_root_serialized;
    bytes merkle_leaf_serialized;
    bytes merkle_path_serialized;

    error VerificationFailed();

    function run() public {
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        proof_hash_serialized = vm.readFileBinary("proof_hash.bin");
        merkle_root_serialized = vm.readFileBinary("merkle_root.bin");
        merkle_leaf_serialized = vm.readFileBinary("merkle_leaf.bin");
        merkle_path_serialized = vm.readFileBinary("merkle_path.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_proof_hash(proof_hash_serialized);
        verifier.store_potential_merkle_root(merkle_root_serialized);

        verifier.full_verify();

        if (!verifier.is_last_proof_valid()) {
            revert VerificationFailed();
        }

        vm.stopBroadcast();
    }
}

contract VerifyAndCheckAccount is Script {
    bytes linearization_literals_serialized;
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes proof_hash_serialized;
    bytes merkle_root_serialized;
    bytes merkle_leaf_serialized;
    bytes merkle_path_serialized;

    error VerificationFailed();
    error MerkleFailed();

    function run() public {
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        proof_hash_serialized = vm.readFileBinary("proof_hash.bin");
        merkle_root_serialized = vm.readFileBinary("merkle_root.bin");
        merkle_leaf_serialized = vm.readFileBinary("merkle_leaf.bin");
        merkle_path_serialized = vm.readFileBinary("merkle_path.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_proof_hash(proof_hash_serialized);
        verifier.store_potential_merkle_root(merkle_root_serialized);

        bool verify_success = verifier.full_verify();

        if (!verify_success) {
            revert VerificationFailed();
        }

        bool merkle_success = verifier.verify_account_inclusion(bytes32(merkle_leaf_serialized), merkle_path_serialized);

        if (!merkle_success) {
            revert MerkleFailed();
        }

        vm.stopBroadcast();
    }
}

contract PartialAndFinalVerify is Script {
    bytes linearization_literals_serialized;
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes proof_hash_serialized;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address verifierAddress = vm.envAddress("CONTRACT_ADDRESS");
        KimchiVerifier verifier = KimchiVerifier(verifierAddress);

        verifier.partial_verify_and_store();
        verifier.final_verify_and_store();
        console.log("is proof valid?: %s", verifier.is_last_proof_valid());

        vm.stopBroadcast();
    }
}

contract MerkleVerify is Script {
    bytes merkle_leaf_serialized;
    bytes merkle_path_serialized;

    function run() public {
        merkle_leaf_serialized = vm.readFileBinary("merkle_leaf.bin");
        merkle_path_serialized = vm.readFileBinary("merkle_path.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address verifierAddress = vm.envAddress("CONTRACT_ADDRESS");
        KimchiVerifier verifier = KimchiVerifier(verifierAddress);

        bool success = verifier.verify_account_inclusion(bytes32(merkle_leaf_serialized), merkle_path_serialized);
        console.log("is account included in verified state?: %s", success);

        vm.stopBroadcast();
    }
}
