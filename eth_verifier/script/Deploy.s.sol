// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import {KimchiVerifierDemo} from "../src/VerifierDemo.sol";
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

        KimchiVerifierDemo verifier = new KimchiVerifierDemo();

        bool success = verifier.verify_state(vm.readFileBinary("state.mpk"), vm.readFileBinary("proof.mpk"));
        console.log(success);

        vm.stopBroadcast();
    }
}
