// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "poseidon/Sponge.sol";
import "pasta/Fields.sol";
import "merkle/Verify.sol";

contract MerkleTest is Test {
    Poseidon poseidon_sponge_contract;
    MerkleVerifier merkle_verifier;

    function setUp() public {
        poseidon_sponge_contract = new Poseidon();
        merkle_verifier = new MerkleVerifier();
    }

    function test_depth_1_proof() public {
        MerkleVerifier.PathElement[]
            memory merkle_path = new MerkleVerifier.PathElement[](1);
        merkle_path[0] = MerkleVerifier.PathElement(
            Pasta.from(42),
            MerkleVerifier.LeftOrRight.Left
        );

        Pasta.Fp leaf_hash = Pasta.from(80);

        Pasta.Fp root = merkle_verifier.calc_path_root(
            merkle_path,
            leaf_hash,
            poseidon_sponge_contract
        );

        assertEq(
            Pasta.Fp.unwrap(root),
            586916851671628937271642655597333396477811635876932869114437365941107007713
        );
    }

    function test_depth_2_proof() public {
        MerkleVerifier.PathElement[]
            memory merkle_path = new MerkleVerifier.PathElement[](2);
        merkle_path[0] = MerkleVerifier.PathElement(
            Pasta.from(42),
            MerkleVerifier.LeftOrRight.Left
        );
        merkle_path[1] = MerkleVerifier.PathElement(
            Pasta.from(28),
            MerkleVerifier.LeftOrRight.Right
        );

        Pasta.Fp leaf_hash = Pasta.from(80);

        Pasta.Fp root = merkle_verifier.calc_path_root(
            merkle_path,
            leaf_hash,
            poseidon_sponge_contract
        );

        assertEq(
            Pasta.Fp.unwrap(root),
            20179372078419284495777784494767897705526278687856314176984937187561031505424
        );
    }
}
