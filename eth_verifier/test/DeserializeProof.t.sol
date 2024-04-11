// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/Proof.sol";
import "../lib/Constants.sol";
import "../lib/VerifierIndex.sol";
import "../lib/msgpack/Deserialize.sol";

contract DeserializeProof is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized_rlp;
    bytes public_inputs_serialized;

    ProverProof proof;
    VerifierIndex verifier_index;
    URS urs;
    Scalar.FE[] public_inputs;

    function setUp() public {
        verifier_index_serialized = vm.readFileBinary("./verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("./prover_proof.bin");
        linearization_serialized_rlp = vm.readFileBinary("./linearization.rlp");
        public_inputs_serialized = vm.readFileBinary("./public_inputs.mpk");
    }

    // Measure proof deserialization
    function test_deserialize_proof() public {
        MsgPk.deser_verifier_index(MsgPk.new_stream(verifier_index_serialized), verifier_index);
        deser_prover_proof(prover_proof_serialized, proof);
        verifier_index.linearization = abi.decode(linearization_serialized_rlp, (Linearization));
        public_inputs = MsgPk.deser_public_inputs(public_inputs_serialized);

        require(keccak256(abi.encode(verifier_index.sponge)) > 0);
        require(keccak256(abi.encode(public_inputs_serialized)) > 0);
    }
}
