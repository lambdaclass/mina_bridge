// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {KimchiVerifier, Kimchi} from "../src/Verifier.sol";
import {BN254} from "../src/BN254.sol";
import "../src/Fields.sol";
import "../src/msgpack/Deserialize.sol";

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
        bytes
            memory opening_proof_serialized = hex"92c42004082c5fa22d4d2bf78f2aa71269510911c1b414b8bedfe41afb3c7147f99325c42017a3bfd724d88bf23ed3d13155cd09c0a4d1d1d520b869599f00958810100621";

        Kimchi.ProverProof memory proof = MsgPk.deserializeOpeningProof(
            opening_proof_serialized
        );

        BN254.G1Point memory expected_quotient = BN254.g1Deserialize(
            0x04082c5fa22d4d2bf78f2aa71269510911c1b414b8bedfe41afb3c7147f99325
        );
        uint256 expected_blinding = 0x17a3bfd724d88bf23ed3d13155cd09c0a4d1d1d520b869599f00958810100621;

        assertEq(
            proof.opening_proof_blinding,
            expected_blinding,
            "wrong blinding"
        );
        assertEq(
            proof.opening_proof_quotient.x,
            expected_quotient.x,
            "wrong quotient x"
        );
        assertEq(
            proof.opening_proof_quotient.y,
            expected_quotient.y,
            "wrong quotient y"
        );
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
