// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import "../lib/expr/Expr.sol";
import "../lib/VerifierIndex.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/deserialize/VerifierIndex.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/deserialize/PublicInputs.sol";

contract Profiling is Test {
    Linearization linearization;
    VerifierIndex verifier_index;
    ProverProof prover_proof;
    Scalar.FE public_input;

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("linearization.mpk");
        MsgPk.deser_linearization(MsgPk.new_stream(linearization_serialized), verifier_index);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_decode_linearization_profiling_only() public {
        bytes memory linearization_rlp = vm.readFileBinary("linearization.rlp");
        linearization = abi.decode(linearization_rlp, (Linearization));
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
    function test_deserialize_public_input_profiling_only() public {
        bytes memory public_input_serialized = vm.readFileBinary("public_input.bin");
        public_input = deser_public_input(public_input_serialized);
    }
}
