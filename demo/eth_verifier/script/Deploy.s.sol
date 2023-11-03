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

contract DeployState is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();

        bytes memory state_data = hex"42";
        verifier.store(state_data);

        bytes memory retrieved_data = verifier.retrieve();
        console.log(uint8(bytes1(retrieved_data)));

        vm.stopBroadcast();
    }
}
