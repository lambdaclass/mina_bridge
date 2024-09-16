// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {MinaBridge} from "../src/MinaBridge.sol";

contract MinaBridgeTest is Test {
    MinaBridge public bridge;
    address payable alignedServiceAddress = payable(0x0);

    function setUp() public {
        // FIXME(xqft): this script may be deprecated, for now we'll
        // pass 0x0 as the second constructor argument.
        bridge = new MinaBridge(alignedServiceAddress, 0x0);
    }
}
