// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MinaBridge} from "../src/MinaBridge.sol";

contract MinaBridgeTest is Test {
    MinaBridge public bridge;

    function setUp() public {
        bridge = new MinaBridge();
    }
}
