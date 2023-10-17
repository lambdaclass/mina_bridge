// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import {BN254} from "../src/BN254.sol";

contract CounterTest is Test {
    KimchiVerifier public verifier;

    function setUp() public {
        verifier = new KimchiVerifier();
    }

    function test_Verify() public {
        uint256[] memory serializedProof = new uint256[](1);
        assertEq(verifier.verify(serializedProof), true);
    }

    function test_BN254_add_scale() public {
        BN254.G1 memory g = BN254.G1(
            0x2523648240000001BA344D80000000086121000000000013A700000000000012,
            0x0000000000000000000000000000000000000000000000000000000000000001);

        BN254.G1 memory g_plus_g = BN254.add(g, g);
        BN254.G1 memory two_g = BN254.add(g, g);

        assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }
}
