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
import "../lib/deserialize/ProverProof.sol";

contract KimchiVerifierTest is Test {
    bytes verifier_index_serialized;
    bytes prover_proof_serialized;
    bytes urs_serialized;
    bytes linearization_serialized_rlp;
    bytes public_inputs_serialized;

    VerifierIndex test_verifier_index;
    Sponge sponge;

    function setUp() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        urs_serialized = vm.readFileBinary("urs.mpk");
        linearization_serialized_rlp = vm.readFileBinary("linearization.rlp");
        public_inputs_serialized = vm.readFileBinary("public_inputs.bin");

        // we store deserialized structures mostly to run intermediate results
        // tests.
        MsgPk.deser_verifier_index(
            MsgPk.new_stream(vm.readFileBinary("unit_test_data/verifier_index.mpk")), test_verifier_index
        );
    }

    function test_verify_with_index() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        require(success, "Verification failed!");
    }

    function test_partial_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        verifier.deserialize_proof(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        AggregatedEvaluationProof memory agg_proof = verifier.partial_verify();

        // Necessary so that the optimized compiler takes into account the partial verification
        require(keccak256(abi.encode(agg_proof)) > 0);
    }

    function test_eval_commitment() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        verifier.deserialize_proof(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        Scalar.FE[2] memory evaluation_points = [
            Scalar.from(13611645662807726448009836376915752628632570551277086161653783406622791783728),
            Scalar.from(3564135020345995638717498554909006524700441992279926422621219017070650554254)
        ];

        Scalar.FE[] memory evals = new Scalar.FE[](2);
        evals[0] = Scalar.from(10120666028354925241544739361936737942150226600838550203372747067710839915497);
        evals[1] = Scalar.from(15078030357868247450073031446158725935649265148599941249555157207050719642652);

        BN254.G1Point[] memory g = new BN254.G1Point[](2);
        g[0] = BN254.G1Point(1, 2);
        g[1] = BN254.G1Point(
            4312786488925573964619847916436127219510912864504589785209181363209026354996,
            16161347681839669251864665467703281411292235435048747094987907712909939880451
        );
        URS memory full_urs = URS(g, BN254.point_at_inf());

        BN254.G1Point memory eval_commitment = verifier.eval_commitment(evaluation_points, evals, full_urs);

        // Necessary so that the optimized compiler takes into account the eval commitment
        require(keccak256(abi.encode(eval_commitment)) > 0);
    }

    function test_divisor_commitment() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        verifier.deserialize_proof(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        Scalar.FE[2] memory evaluation_points = [
            Scalar.from(13611645662807726448009836376915752628632570551277086161653783406622791783728),
            Scalar.from(3564135020345995638717498554909006524700441992279926422621219017070650554254)
        ];

        BN254.G2Point memory divisor_commitment = verifier.divisor_commitment(evaluation_points);

        // Necessary so that the optimized compiler takes into account the divisor commitment
        require(keccak256(abi.encode(divisor_commitment)) > 0);
    }

    function test_public_commitment() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        verifier.deserialize_proof(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );

        BN254.G1Point memory public_commitment = verifier.public_commitment();

        // Necessary so that the optimized compiler takes into account the public commitment
        require(keccak256(abi.encode(public_commitment)) > 0);
    }

    // INFO: Disabled test because the new serializer isnt't used yet to
    // generate unit test data.
    //function test_absorb_evaluations() public {
    //    KeccakSponge.reinit(sponge);
    //    KeccakSponge.absorb_evaluations(sponge, test_prover_proof.evals);
    //    Scalar.FE scalar = KeccakSponge.challenge_scalar(sponge);
    //    assertEq(Scalar.FE.unwrap(scalar), 0x0000000000000000000000000000000000DC56216206DF842F824D14A6D87024);
    //}

    function test_eval_vanishing_poly_on_last_n_rows() public {
        // hard-coded zeta is taken from executing the verifier in main.rs
        // the value doesn't matter, as long as it matches the analogous test in Rust.
        Scalar.FE zeta = Scalar.from(0x1B427680FC915CB850FFF8701AD7E2D73B9F1349F713BFBE6B58E5D007988CD0);
        Scalar.FE permutation_vanishing_poly = Polynomial.eval_vanishes_on_last_n_rows(
            test_verifier_index.domain_gen, test_verifier_index.domain_size, test_verifier_index.zk_rows, zeta
        );
        assertEq(
            Scalar.FE.unwrap(permutation_vanishing_poly),
            0x1AEE30761864581115514430C6BD95502BB8DE7CD8C6B608F27BA1C03E80BFFB
        );
    }
}
