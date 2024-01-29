// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BN254} from "../lib/bn254/BN254.sol";

contract DeserializeTest is Test {
    function test_BN254_add_scale() public {
        BN254.G1Point memory g = BN254.P1();

        BN254.G1Point memory g_plus_g = BN254.add(g, g);
        BN254.G1Point memory two_g = BN254.add(g, g);

        assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }
}
