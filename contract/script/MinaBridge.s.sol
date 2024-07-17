// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MinaBridge} from "../src/MinaBridge.sol";

contract MinaBridgeScript is Script {
    MinaBridge public bridge;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        bridge = new MinaBridge();

        vm.stopBroadcast();
    }
}
