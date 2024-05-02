// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        vm.stopBroadcast();
    }
}

contract DeployAndDeser is Script {
    bytes verifier_index_serialized;

    function run() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);

        vm.stopBroadcast();
    }
}
