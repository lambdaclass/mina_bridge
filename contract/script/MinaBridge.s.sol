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
        address payable alignedServiceAddress;
        if (keccak256(bytes(chain)) == keccak256("devnet")) {
            alignedServiceAddress = payable(0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8);
        } else if (keccak256(bytes(chain)) == keccak256("holesky")) {
            alignedServiceAddress = payable(0x58F280BeBE9B34c9939C3C39e0890C81f163B623);
        } else {
            revert UndefinedChain();
        }

        // FIXME(xqft): this script may be deprecated, for now we'll
        // pass 0x0 as the second constructor argument.
        new MinaBridge(alignedServiceAddress, 0x0);

        vm.stopBroadcast();
    }
}
