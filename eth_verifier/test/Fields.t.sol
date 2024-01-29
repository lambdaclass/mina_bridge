// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test } from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Scalar, Base} from "../lib/bn254/Fields.sol";
import "../lib/bn254/BN256G2.sol";
import "../lib/bn254/BN254.sol";
import "../lib/Oracles.sol";

using { Base.add, Base.mul, Base.inv } for Base.FE;
using { Scalar.add, Scalar.mul, Scalar.inv } for Scalar.FE;
using { Oracles.to_field } for Oracles.ScalarChallenge;

contract FieldsTest is Test {
    function test_add_base() public {
        Base.FE q = Base.FE.wrap(Base.MODULUS - 1);
        Base.FE one = Base.FE.wrap(1);

        Base.FE q_plus_one = q.add(one);
        assertEq(Base.FE.unwrap(q_plus_one), 0, "p != 0 mod p");
    }

    function test_add_scalar() public {
        Scalar.FE q = Scalar.FE.wrap(Scalar.MODULUS - 1);
        Scalar.FE one = Scalar.FE.wrap(1);

        Scalar.FE q_plus_one = q.add(one);
        assertEq(Scalar.FE.unwrap(q_plus_one), 0, "p != 0 mod p");
    }

    function test_inv_base() public {
        Base.FE a = Base.from(Base.MODULUS - 1);
        Base.FE b = a.inv();

        Base.FE one = Base.from(1);
        assertEq(Base.FE.unwrap(a.mul(b)), 1, "a * a.inv() != 1");
    }

    function test_inv_scalar() public {
        Scalar.FE a = Scalar.from(42);
        Scalar.FE b = a.inv();

        Scalar.FE one = Scalar.from(1);
        assertEq(Scalar.FE.unwrap(a.mul(b)), 1, "a * a.inv() != 1");
    }

    function test_fq2_sqrt() public {
        uint256 MODULUS = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
        (uint256 a0, uint256 a1) = BN256G2._FQ2Mul(42, 42, 42, 42);
        (uint256 x0, uint256 x1) = BN256G2.FQ2Sqrt(a0, a1);

        assertEq(x0, MODULUS - 42);
        assertEq(x1, MODULUS - 42);
    }

    function test_scalar_challenge_to_field() public {
        Oracles.ScalarChallenge memory chal = Oracles.ScalarChallenge(Scalar.from(42));
        (Base.FE _endo_q, Scalar.FE endo_r) = BN254.endo_coeffs_g1();
        assertEq(
            Scalar.FE.unwrap(chal.to_field(endo_r)),
            0x1B98C45C863AD2A1F4EB90EFBC8F1104AF5534B239720D63ECB7156E9347F622
        );
    }
}
