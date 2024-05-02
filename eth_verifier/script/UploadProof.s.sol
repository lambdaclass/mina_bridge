// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract UploadProof is Script {
    bytes linearization_serialized;
    bytes public_input_serialized;
    bytes prover_proof_serialized;

    function run() public {
        linearization_serialized = vm.readFileBinary("linearization.bin");
        public_input_serialized = vm.readFileBinary("public_input.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address verifierAddress = vm.envAddress("CONTRACT_ADDRESS");
        KimchiVerifier verifier = KimchiVerifier(verifierAddress);

        verifier.store_literal_tokens(linearization_serialized);
        verifier.store_public_input(public_input_serialized);
        verifier.store_prover_proof(prover_proof_serialized);

        vm.stopBroadcast();
    }
}
