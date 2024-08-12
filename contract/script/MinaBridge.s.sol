// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {MinaBridge} from "../src/MinaBridge.sol";

error UndefinedChain();

contract MinaBridgeDeployer is Script {
    MinaBridge public bridge;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        string memory chain = vm.envString("ETH_CHAIN");
        address alignedServiceAddress;
        if (keccak256(bytes(chain)) == keccak256("devnet")) {
            alignedServiceAddress = address(
                uint160(0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8)
            );
        } else if (keccak256(bytes(chain)) == keccak256("holesky")) {
            alignedServiceAddress = address(
                uint160(0xe41Faf6446A94961096a1aeeec1268CA4A6D4a77)
            );
        } else {
            revert UndefinedChain();
        }

        // FIXME(xqft): this script may be deprecated, for now we'll
        // pass 0x0 as the second constructor argument.
        new MinaBridge(alignedServiceAddress, 0x0);

        vm.stopBroadcast();
    }
}
