// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {KimchiVerifier, Kimchi} from "../src/Verifier.sol";
import {BN254} from "../src/BN254.sol";
import "../src/Fields.sol";

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
        BN254.G1Point memory g = BN254.P1();

        BN254.G1Point memory g_plus_g = BN254.add(g, g);
        BN254.G1Point memory two_g = BN254.add(g, g);

        assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }

    function test_deserialize_opening_proof() public {
        uint8[69] memory opening_proof_serialized = [
            0x92, 0xc4, 0x20, 0x04, 0x08, 0x2c, 0x5f, 0xa2,
            0x2d, 0x4d, 0x2b, 0xf7, 0x8f, 0x2a, 0xa7, 0x12,
            0x69, 0x51, 0x09, 0x11, 0xc1, 0xb4, 0x14, 0xb8,
            0xbe, 0xdf, 0xe4, 0x1a, 0xfb, 0x3c, 0x71, 0x47,
            0xf9, 0x93, 0x25, 0xc4, 0x20, 0x17, 0xa3, 0xbf,
            0xd7, 0x24, 0xd8, 0x8b, 0xf2, 0x3e, 0xd3, 0xd1,
            0x31, 0x55, 0xcd, 0x09, 0xc0, 0xa4, 0xd1, 0xd1,
            0xd5, 0x20, 0xb8, 0x69, 0x59, 0x9f, 0x00, 0x95,
            0x88, 0x10, 0x10, 0x06, 0x21
        ];

        Kimchi.ProverProof memory proof = Kimchi.deserializeOpeningProof(
            opening_proof_serialized
        );

        BN254.G1Point memory expected_quotient = BN254.g1Deserialize(0x04082c5fa22d4d2bf78f2aa71269510911c1b414b8bedfe41afb3c7147f99325);
        uint256 expected_blinding = 0x17a3bfd724d88bf23ed3d13155cd09c0a4d1d1d520b869599f00958810100621;

        console.log(proof.opening_proof_blinding);
        assertEq(proof.opening_proof_blinding, expected_blinding, "wrong blinding");
        assertEq(proof.opening_proof_quotient.x, expected_quotient.x, "wrong quotient x");
        assertEq(proof.opening_proof_quotient.y, expected_quotient.y, "wrong quotient y");
    }

    /*
[
    0x92,
    0x91,
    0xc4,
    0x20,
    0x1,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x91,
    0xc4,
    0x20,
    0x1,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
]
 */

    function test_PartialVerify() public {
        Scalar.FE[] memory public_inputs = new Scalar.FE[](0);
        verifier.set_verifier_index_for_testing();
        verifier.partial_verify(public_inputs);
    }
}
