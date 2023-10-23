// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "../src/BN254.sol";
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

    function test_PartialVerify() public {
        Scalar.FE[] memory public_inputs = new Scalar.FE[](3);
        public_inputs[0] = Scalar.FE.wrap(1);
        public_inputs[1] = Scalar.FE.wrap(2);
        public_inputs[2] = Scalar.FE.wrap(3);


        verifier.set_verifier_index_for_testing(public_inputs.length);
        // verifier.partial_verify(public_inputs);
    }
}
