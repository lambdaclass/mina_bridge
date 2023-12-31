// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Verifier.sol";
import "../lib/bn254/BN254.sol";
import "../lib/bn254/Fields.sol";
import "../lib/msgpack/Deserialize.sol";

contract CounterTest is Test {
    function test_BN254_add_scale() public {
        BN254.G1Point memory g = BN254.P1();

        BN254.G1Point memory g_plus_g = BN254.add(g, g);
        BN254.G1Point memory two_g = BN254.add(g, g);

        assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }

    function test_pairing_check() public {
        bytes
            memory proof = hex"14e0a4821232d154c9fb632f8ec6c53dbb2fc582fade0b02b99d84ec4a43f1a821a85cb9074899463d61652bc3d0ed1f2c2e60bb1e2608f696bbf2e99070f18d1a426ef2110034a4d16315a6d27490e613bd25a48c0f955e68da777bfcfe4147191d7c091cd01079d455e3c8dc36ea9756516d8cce85c4d632df254a99e506cc2b8da15034a505d3ed3a45da327cc2356eadb395a6a1f8747230f054f13e67f415f4c7725cd58d61fcdc60dd9ad2200284c88f12a86007b55665d9cf6a3dae81210342bb436029b5c84fd59c488f8e5ab42aacdae4c16c6f4208fc62ec1973031dd79d5b61384f752c7a597e28778632215360003a12d3f316d5dc460c39be6c";
        (
            BN254.G1Point memory numerator,
            BN254.G1Point memory quotient,
            BN254.G2Point memory divisor
        ) = MsgPk.deserializeFinalCommitments(proof);

        assert(BN254.pairingProd2(numerator, BN254.P2(), quotient, divisor));
    }
}
