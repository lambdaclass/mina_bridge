// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "poseidon/Sponge.sol";
import "pasta/Fields.sol";

contract PoseidonTest is Test {
    Poseidon poseidon_sponge_contract;

    function setUp() public {
        poseidon_sponge_contract = new Poseidon();
    }

    function test_squeeze() public {
        Poseidon.Sponge memory sponge = poseidon_sponge_contract
            .new_sponge();

        (
            Poseidon.Sponge memory _s,
            Pasta.Fp result
        ) = poseidon_sponge_contract.squeeze(sponge);
        assertEq(
            Pasta.Fp.unwrap(result),
            0x2fadbe2852044d028597455bc2abbd1bc873af205dfabb8a304600f3e09eeba8
        );
    }

    function test_absorb_squeeze() public {
        Poseidon.Sponge memory sponge = poseidon_sponge_contract
            .new_sponge();
        Pasta.Fp input = Pasta.Fp.wrap(
            0x36fb00ad544e073b92b4e700d9c49de6fc93536cae0c612c18fbe5f6d8e8eef2
        );
        sponge = poseidon_sponge_contract.absorb(sponge, input);

        (
            Poseidon.Sponge memory _s,
            Pasta.Fp result
        ) = poseidon_sponge_contract.squeeze(sponge);
        assertEq(
            Pasta.Fp.unwrap(result),
            0x3d4f050775295c04619e72176746ad1290d391d73ff4955933f9075cf69259fb
        );
    }

    function test_absorb_absorb_squeeze() public {
        Poseidon.Sponge memory sponge = poseidon_sponge_contract
            .new_sponge();
        Pasta.Fp input = Pasta.Fp.wrap(
            0x3793e30ac691700012baf26bb813d6d70bd379beed8050a1deee3c188f1c3fbd
        );
        Pasta.Fp input2 = Pasta.Fp.wrap(
            0x2fc4c98e50e0b1aae6ecb468e28c0b7d80a7e0eec7136db0ba0677b84af0e465
        );
        sponge = poseidon_sponge_contract.absorb(sponge, input);
        sponge = poseidon_sponge_contract.absorb(sponge, input2);

        (
            Poseidon.Sponge memory _s,
            Pasta.Fp result
        ) = poseidon_sponge_contract.squeeze(sponge);
        assertEq(
            Pasta.Fp.unwrap(result),
            0x336c73d08ad408ceb7d1264867096f0817a1d0558b313312a1207602f23624fe
        );
    }
}
