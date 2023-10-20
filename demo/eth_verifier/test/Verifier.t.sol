// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {KimchiVerifier, Kimchi} from "../src/Verifier.sol";
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
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        //BN254.G1 memory g_plus_g = BN254.add(g, g);
        //BN254.G1 memory two_g = BN254.add(g, g);

        //assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        //assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }

    function test_deserialize_opening_proof() public {
        uint8[69] memory opening_proof_serialized = [
            146,
            196,
            32,
            206,
            108,
            109,
            113,
            24,
            237,
            66,
            118,
            165,
            236,
            166,
            177,
            0,
            15,
            82,
            70,
            40,
            68,
            179,
            201,
            98,
            7,
            86,
            150,
            235,
            11,
            249,
            93,
            34,
            24,
            67,
            45,
            196,
            32,
            249,
            31,
            116,
            99,
            63,
            0,
            7,
            93,
            37,
            8,
            132,
            230,
            138,
            198,
            194,
            133,
            57,
            58,
            197,
            202,
            13,
            98,
            136,
            31,
            65,
            245,
            86,
            201,
            47,
            136,
            174,
            15
        ];

        Kimchi.ProverProof memory proof = Kimchi.deserializeProof(
            opening_proof_serialized
        );
    }
}
