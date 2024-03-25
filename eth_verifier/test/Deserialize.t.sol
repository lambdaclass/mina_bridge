// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/deserialize/PairingProof.sol";
import "../lib/Proof.sol";

contract DeserializeTest is Test {
    bytes pairing_proof_bytes;
    NewPairingProof pairing_proof;

    function setUp() public {
        pairing_proof_bytes = vm.readFileBinary(
            "./unit_test_data/pairing_proof.bin"
        );
    }

    function test_new_deser_pairing_proof() public {
        deser_pairing_proof(pairing_proof_bytes, pairing_proof);

        assertEq(pairing_proof.quotient.x, 1);
        assertEq(pairing_proof.quotient.y, 2);
        assertEq(Scalar.FE.unwrap(pairing_proof.blinding), 1);
    }
}
