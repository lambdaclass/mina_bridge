// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {MinaBridge} from "../src/MinaBridge.sol";

contract MinaBridgeScript is Script {
    MinaBridge public bridge;
    uint160 alignedServiceAddress = 0x0;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        bridge = new MinaBridge(address(alignedServiceAddress));

        vm.stopBroadcast();
    }
}
