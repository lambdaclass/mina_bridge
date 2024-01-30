// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Commitment.sol";
import "../lib/Alphas.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes urs_serialized;
    bytes32 numerator_binary;

    function setUp() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("prover_proof.mpk");
        urs_serialized = vm.readFileBinary("urs.mpk");
        numerator_binary = bytes32(vm.readFileBinary("numerator.bin"));
    }

    function test_verify_with_index() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized,
            numerator_binary
        );

        require(success, "Verification failed!");
    }

    function test_partial_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);
        verifier.deserialize_proof(verifier_index_serialized, prover_proof_serialized);
        verifier.partial_verify(new Scalar.FE[](0));
    }
}
