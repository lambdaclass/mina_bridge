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

    function depth_1_proof_test() public view {
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

        console.logBytes(abi.encode(root));
    }
}
