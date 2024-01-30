// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes urs_serialized;
    bytes32 numerator_binary =
        0x760553641e13f70f3c75d4e3f8ffc1e46024507d1d363af1dc1177fd9c863c05;

    function run() public {
        urs_serialized = vm.readFileBinary("urs.mpk");
        verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("prover_proof.mpk");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized,
            numerator_binary
        );

        require(success, "Verification failed.");

        vm.stopBroadcast();
    }
}
