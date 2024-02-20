// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Commitment.sol";
import "../lib/Alphas.sol";
import "../lib/Polynomial.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes urs_serialized;
    bytes linearization_serialized;
    bytes32 numerator_binary;

    ProverProof test_prover_proof;
    VerifierIndex test_verifier_index;
    Sponge sponge;

    function setUp() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("prover_proof.mpk");
        urs_serialized = vm.readFileBinary("urs.mpk");
        linearization_serialized = vm.readFileBinary("linearization.mpk");
        numerator_binary = bytes32(vm.readFileBinary("numerator.bin"));

        // we store deserialized structures mostly to run intermediate results
        // tests.
        MsgPk.deser_prover_proof(
            MsgPk.new_stream(
                vm.readFileBinary("unit_test_data/prover_proof.mpk")
            ),
            test_prover_proof
        );
        MsgPk.deser_verifier_index(
            MsgPk.new_stream(
                vm.readFileBinary("unit_test_data/verifier_index.mpk")
            ),
            test_verifier_index
        );
        MsgPk.deser_linearization(
            MsgPk.new_stream(
                vm.readFileBinary("unit_test_data/linearization.mpk")
            ),
            test_verifier_index
        );
    }

    function test_verify_with_index() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized,
            linearization_serialized,
            numerator_binary
        );

        require(success, "Verification failed!");
    }

    function test_absorb_evaluations() public {
        KeccakSponge.reinit(sponge);

        KeccakSponge.absorb_evaluations(sponge, test_prover_proof.evals);
        Scalar.FE scalar = KeccakSponge.challenge_scalar(sponge);
        assertEq(
            Scalar.FE.unwrap(scalar),
            0x0000000000000000000000000000000000DC56216206DF842F824D14A6D87024
        );
    }

    function test_eval_vanishing_poly_on_last_n_rows() public {
        // hard-coded zeta is taken from executing the verifier in main.rs
        // the value doesn't matter, as long as it matches the analogous test in Rust.
        Scalar.FE zeta = Scalar.from(
            0x1B427680FC915CB850FFF8701AD7E2D73B9F1349F713BFBE6B58E5D007988CD0
        );
        Scalar.FE permutation_vanishing_poly = Polynomial
            .eval_vanishes_on_last_n_rows(
                test_verifier_index.domain_gen,
                test_verifier_index.domain_size,
                test_verifier_index.zk_rows,
                zeta
            );
        assertEq(
            Scalar.FE.unwrap(permutation_vanishing_poly),
            0x2C5ACDAC911B82AE9F3E0D0D792DFEAC4638C8F482B99116BDC080527F5DEB7E
        );
    }
}
