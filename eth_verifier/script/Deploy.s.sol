// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new KimchiVerifier();

        vm.stopBroadcast();
    }
}

contract DeployAndVerify is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        bool success = verifier.verify_state(
            vm.readFileBinary("state.mpk"),
            vm.readFileBinary("proof.mpk")
        );
        console.log(success);

        vm.stopBroadcast();
    }
}
