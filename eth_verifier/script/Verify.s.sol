// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes linearization_serialized;
    bytes public_input_serialized;

    function run() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup();

        bool success = verifier.full_verify(
            verifier_index_serialized, linearization_serialized, prover_proof_serialized, public_input_serialized
        );

        require(success, "Verification failed.");

        vm.stopBroadcast();
    }
}
