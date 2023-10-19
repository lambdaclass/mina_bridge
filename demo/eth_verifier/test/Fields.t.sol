// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test } from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Scalar, Base} from "../src/Fields.sol";

using { Base.add, Base.mul, Base.inv } for Base.FE;
using { Scalar.add, Scalar.mul, Scalar.inv } for Scalar.FE;

contract FieldsTest is Test {
    function test_add_base() public {
        Base.FE q = Base.FE.wrap(Base.MODULUS - 1);
        Base.FE one = Base.FE.wrap(1);

        Base.FE q_plus_one = q.add(one);
        assertEq(Base.FE.unwrap(q_plus_one), 0, "p == 0 mod p");
    }

    function test_add_scalar() public {
        Scalar.FE q = Scalar.FE.wrap(Scalar.MODULUS - 1);
        Scalar.FE one = Scalar.FE.wrap(1);

        Scalar.FE q_plus_one = q.add(one);
        assertEq(Scalar.FE.unwrap(q_plus_one), 0, "p == 0 mod p");
    }
}
