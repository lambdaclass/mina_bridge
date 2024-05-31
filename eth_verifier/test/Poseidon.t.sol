// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "poseidon/Sponge.sol";
import "pasta/Fields.sol";

contract PoseidonTest is Test {
    PoseidonSponge poseidon_sponge_contract;

    function setUp() public {
        poseidon_sponge_contract = new PoseidonSponge();
    }

    function test_squeeze() public {
        PoseidonSponge.Sponge memory sponge;

        Pasta.Fp result = poseidon_sponge_contract.squeeze(sponge);
        assertEq(
            Pasta.Fp.unwrap(result),
            0xa8eb9ee0f30046308abbfa5d20af73c81bbdabc25b459785024d045228bead2f
        );
    }

    function test_absorb_squeeze() public {}

    function test_2absorb_squeeze() public {}
}
