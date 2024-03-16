// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes urs_serialized;
    bytes linearization_serialized_rlp;
    bytes public_inputs_serialized;
    bytes lagrange_bases_serialized;

    function run() public {
        urs_serialized = vm.readFileBinary("urs.mpk");
        verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("prover_proof.mpk");
        linearization_serialized_rlp = vm.readFileBinary("linearization.rlp");
        public_inputs_serialized = vm.readFileBinary("public_inputs.mpk");
        lagrange_bases_serialized = vm.readFileBinary("lagrange_bases.mpk");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized,
            linearization_serialized_rlp,
            public_inputs_serialized,
            lagrange_bases_serialized
        );

        require(!success, "Verification failed.");

        vm.stopBroadcast();
    }
}
