// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(vm.readFileBinary("urs.mpk"));

        bool success = verifier.verify_with_index(
            vm.readFileBinary("verifier_index.mpk"),
            vm.readFileBinary("proof.mpk")
        );
        console.log(success);

        vm.stopBroadcast();
    }
}
