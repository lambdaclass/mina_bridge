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
    bytes public_input_serialized;

    function run() public {
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);

        bool success = verifier.full_verify();

        require(success, "Verification failed.");

        vm.stopBroadcast();
    }
}

contract PartialAndFinalVerify is Script {
    bytes linearization_literals_serialized;
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes public_input_serialized;

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
