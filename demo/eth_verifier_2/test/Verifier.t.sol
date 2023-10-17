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
}
