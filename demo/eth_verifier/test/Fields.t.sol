// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Scalar, Base} from "../src/Fields.sol";

using { Base.add, Base.mul, Base.inv } for Base.FE;

contract FieldsTest is Test {
    function test_add() public {
        Base.FE q = Base.FE.wrap(Base.MODULUS - 1);
        Base.FE one = Base.FE.wrap(1);
        assertEq(Base.FE.unwrap(q.add(one)), 1, "p == 1 mod p");
    }
}
