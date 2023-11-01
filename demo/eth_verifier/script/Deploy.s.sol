// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import "../lib/BN254.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        new KimchiVerifier();

        vm.stopBroadcast();
    }
}
