// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Scalar, Base} from "../lib/bn254/Fields.sol";
import "../lib/bn254/BN256G2.sol";
import "../lib/bn254/BN254.sol";
import "../lib/Oracles.sol";

using {Oracles.to_field} for Oracles.ScalarChallenge;

contract FieldsTest is Test {
    function test_add_base() public {
        uint256 q = Base.MODULUS - 1;
        uint256 q_plus_one = Base.add(q, 1);
        assertEq(q_plus_one, 0, "p != 0 mod p");
    }

    function test_add_scalar() public {
        uint256 q = Scalar.MODULUS - 1;
        uint256 q_plus_one = Scalar.add(q, 1);
        assertEq(q_plus_one, 0, "p != 0 mod p");
    }

    function test_inv_scalar() public {
        uint256 a = Scalar.from(42);
        uint256 b = Scalar.inv(a);
        assertEq(Scalar.mul(a, b), 1, "a * a.inv() != 1");
    }

    function test_scalar_challenge_to_field() public {
        Oracles.ScalarChallenge memory chal = Oracles.ScalarChallenge(Scalar.from(42));
        (uint256 _endo_q, uint256 endo_r) = BN254.endo_coeffs_g1();
        assertEq(chal.to_field(endo_r), 0x1B98C45C863AD2A1F4EB90EFBC8F1104AF5534B239720D63ECB7156E9347F622);
        // INFO: reference value taken from analogous test in kzg_prover/misc_tests.rs
    }
}
