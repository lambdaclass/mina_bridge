// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract UploadProof is Script {
    bytes verifier_index_serialized;
    bytes linearization_serialized;
    bytes prover_proof_serialized;
    bytes public_input_serialized;

    function run() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address verifierAddress = vm.envAddress("CONTRACT_ADDRESS");
        KimchiVerifier verifier = KimchiVerifier(verifierAddress);

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_public_input(public_input_serialized);

        vm.stopBroadcast();
    }
}
