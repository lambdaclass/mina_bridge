// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import "../lib/BN254.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new KimchiVerifier();

        vm.stopBroadcast();
    }
}
