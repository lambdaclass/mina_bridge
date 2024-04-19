// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import "../lib/expr/Expr.sol";
import "../lib/VerifierIndex.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/deserialize/VerifierIndex.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/deserialize/PublicInputs.sol";
import "../lib/deserialize/Linearization.sol";

contract Profiling is Test {
    Linearization linearization;
    VerifierIndex verifier_index;
    ProverProof prover_proof;
    Scalar.FE[222] public_inputs;

    uint256 linearization_total_variants_len;
    uint256[] linearization_variants;
    uint256[] linearization_mds;
    uint256[] linearization_literals;
    uint256[] linearization_pows;
    uint256[] linearization_loads;

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("linearization.mpk");
        MsgPk.deser_linearization(MsgPk.new_stream(linearization_serialized), verifier_index);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_new_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("linearization.bin");
        linearization_total_variants_len = deser_linearization(
            linearization_serialized,
            linearization_variants,
            linearization_mds,
            linearization_literals,
            linearization_pows,
            linearization_loads
        );
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
    function test_deserialize_public_inputs_profiling_only() public {
        bytes memory public_inputs_serialized = vm.readFileBinary("public_inputs.bin");
        deser_public_inputs(public_inputs_serialized, public_inputs);
    }
}
