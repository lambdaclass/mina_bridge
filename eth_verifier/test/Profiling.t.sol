// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import "../lib/expr/Expr.sol";
import "../lib/VerifierIndex.sol";
import "../lib/deserialize/VerifierIndex.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/deserialize/PublicInputs.sol";
import "../lib/deserialize/Linearization.sol";

contract Profiling is Test {
    Linearization linearization;
    VerifierIndexLib.VerifierIndex verifier_index;
    Proof.ProverProof prover_proof;
    uint256 proof_hash;

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("linearization.bin");
        deser_linearization(linearization_serialized, verifier_index.linearization);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_verifier_index_profiling_only() public {
        bytes memory verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        deser_verifier_index(verifier_index_serialized, verifier_index);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_prover_proof_profiling_only() public {
        bytes memory verifier_index_serialized = vm.readFileBinary("prover_proof.bin");
        deser_prover_proof(verifier_index_serialized, prover_proof);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_proof_hash_profiling_only() public {
        bytes memory proof_hash_serialized = vm.readFileBinary("proof_hash.bin");
        proof_hash = deser_proof_hash(proof_hash_serialized);
    }
}
