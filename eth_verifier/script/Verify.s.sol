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

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup();

        bool success = verifier.verify_with_index(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        require(success, "Verification failed.");

        vm.stopBroadcast();
    }
}
