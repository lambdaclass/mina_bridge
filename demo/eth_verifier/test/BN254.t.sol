// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BN254} from "../src/BN254.sol";

contract DeserializeTest is Test {
    function test_deserialize() public {
        bytes32 input = 0xce6c6d7118ed4276a5eca6b1000f52462844b3c962075696eb0bf95d2218432d;

        BN254.G1Point memory p = BN254.g1Deserialize(input);

        //bytes memory inp
        //assertEq(0, 0, "0 == 0");
    }
}
