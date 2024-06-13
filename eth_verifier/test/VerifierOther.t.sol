// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {BN254} from "../lib/bn254/BN254.sol";
import {KimchiVerifier, VerifierIndexLib} from "../src/Verifier.sol";
import {Commitment} from "../lib/Commitment.sol";
import {Polynomial} from "../lib/Polynomial.sol";
import {deser_verifier_index} from "../lib/deserialize/VerifierIndex.sol";
import {KeccakSponge} from "../lib/sponge/Sponge.sol";
import {Scalar} from "../lib/bn254/Fields.sol";

contract KimchiVerifierTest is Test {
    uint256 internal constant G2_X0 = 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2;
    uint256 internal constant G2_X1 = 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed;
    uint256 internal constant G2_Y0 = 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b;
    uint256 internal constant G2_Y1 = 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa;

    bytes verifier_index_serialized;
    bytes linearization_serialized;
    bytes prover_proof_serialized;
    bytes proof_hash_serialized;

    VerifierIndexLib.VerifierIndex test_verifier_index;
    KeccakSponge.Sponge sponge;

    function setUp() public {
        verifier_index_serialized = vm.readFileBinary("verifier_index.bin");
        linearization_serialized = vm.readFileBinary("linearization.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        proof_hash_serialized = vm.readFileBinary("proof_hash.bin");

        // we store deserialized structures mostly to run intermediate results
        // tests.
        deser_verifier_index(vm.readFileBinary("unit_test_data/verifier_index.bin"), test_verifier_index);
    }

    /*
    function test_eval_commitment() public {
        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup();

        uint256[2] memory evaluation_points = [
            Scalar.from(13611645662807726448009836376915752628632570551277086161653783406622791783728),
            Scalar.from(3564135020345995638717498554909006524700441992279926422621219017070650554254)
        ];

        uint256[] memory evals = new uint256[](2);
        evals[0] = Scalar.from(10120666028354925241544739361936737942150226600838550203372747067710839915497);
        evals[1] = Scalar.from(15078030357868247450073031446158725935649265148599941249555157207050719642652);

        BN254.G1Point[] memory g = new BN254.G1Point[](2);
        g[0] = BN254.G1Point(1, 2);
        g[1] = BN254.G1Point(
            4312786488925573964619847916436127219510912864504589785209181363209026354996,
            16161347681839669251864665467703281411292235435048747094987907712909939880451
        );
        Commitment.URS memory full_urs = Commitment.URS(g, BN254.point_at_inf());

        BN254.G1Point memory eval_commitment = verifier.eval_commitment(evaluation_points, evals, full_urs);

        // Necessary so that the optimized compiler takes into account the eval commitment
        require(keccak256(abi.encode(eval_commitment)) > 0);
    }
    */

    /*
    function test_divisor_commitment() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup();

        verifier.store_verifier_index(verifier_index_serialized);
        verifier.store_linearization(linearization_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_proof_hash(proof_hash_serialized);

        uint256[2] memory evaluation_points = [
            Scalar.from(13611645662807726448009836376915752628632570551277086161653783406622791783728),
            Scalar.from(3564135020345995638717498554909006524700441992279926422621219017070650554254)
        ];

        BN254.G2Point memory divisor_commitment = verifier.divisor_commitment(evaluation_points);

        // Necessary so that the optimized compiler takes into account the divisor commitment
        require(keccak256(abi.encode(divisor_commitment)) > 0);
    }
    */

    // INFO: Disabled test because the new serializer isnt't used yet to
    // generate unit test data.
    //function test_absorb_evaluations() public {
    //    KeccakSponge.reinit(sponge);
    //    KeccakSponge.absorb_evaluations(sponge, test_prover_proof.evals);
    //    uint256 scalar = KeccakSponge.challenge_scalar(sponge);
    //    assertEq(uint256.unwrap(scalar), 0x0000000000000000000000000000000000DC56216206DF842F824D14A6D87024);
    //}

    function test_eval_vanishing_poly_on_last_n_rows() public {
        // hard-coded zeta is taken from executing the verifier in main.rs
        // the value doesn't matter, as long as it matches the analogous test in Rust.
        uint256 zeta = Scalar.from(0x1B427680FC915CB850FFF8701AD7E2D73B9F1349F713BFBE6B58E5D007988CD0);
        uint256 permutation_vanishing_poly = Polynomial.eval_vanishes_on_last_n_rows(
            test_verifier_index.domain_gen, test_verifier_index.domain_size, test_verifier_index.zk_rows, zeta
        );
        assertEq(permutation_vanishing_poly, 0x1AEE30761864581115514430C6BD95502BB8DE7CD8C6B608F27BA1C03E80BFFB);
    }

    function test_pairing() public {
        uint256 out;
        bool success;
        assembly ("memory-safe") {
            let mPtr := mload(0x40)
            //  numerator.x: 10450774816052210382811887210181442163874109730192600906219949320500597203964
            //  numerator.y: 18521096298180617021285508618037348464238256503816928488396642428780381048251

            mstore(mPtr, 10450774816052210382811887210181442163874109730192600906219949320500597203964)
            mstore(add(mPtr, 0x20), 18521096298180617021285508618037348464238256503816928488396642428780381048251)

            mstore(add(mPtr, 0x40), G2_X0)
            mstore(add(mPtr, 0x60), G2_X1)
            mstore(add(mPtr, 0x80), G2_Y0)
            mstore(add(mPtr, 0xa0), G2_Y1)

            //  quotient.x: 9858530704171938310986256537342034831937111088881032382034585534859112842050
            //  quotient.y: 19600521880859631818156218377306900697695708459153218679905962068366758128270
            mstore(add(mPtr, 0xc0), 9858530704171938310986256537342034831937111088881032382034585534859112842050)
            mstore(add(mPtr, 0xe0), 19600521880859631818156218377306900697695708459153218679905962068366758128270)

            //  divisor.x0: 5217525816199090147151875345792296976217988874970195155570400922487612750932
            //  divisor.x1: 4098672365025679336863860792953497130411351839724326987798196532361282943244
            //  divisor.y0: 10756683375305745279332504173914617093624021663287421911939678500359185353540
            //  divisor.y1: 20726890104308532209240308176026341121895900966851824792436596208622727684267

            mstore(add(mPtr, 0x100), 5217525816199090147151875345792296976217988874970195155570400922487612750932)
            mstore(add(mPtr, 0x120), 4098672365025679336863860792953497130411351839724326987798196532361282943244)
            mstore(add(mPtr, 0x140), 10756683375305745279332504173914617093624021663287421911939678500359185353540)
            mstore(add(mPtr, 0x160), 20726890104308532209240308176026341121895900966851824792436596208622727684267)
            success := staticcall(sub(gas(), 2000), 8, mPtr, 0x180, 0x00, 0x20)
            out := mload(0x00)
        }
        require(success, "pairing failed");
        bool pairing_ok = (out != 0);
        assertEq(pairing_ok, true);
    }

    function test_scalar_mul() public {
        BN254.G1Point memory point = BN254.G1Point(1, 2);
        uint256 scalar = 3;
        BN254.G1Point memory result = BN254.scalarMul(point, scalar);
        assertEq(result.x, 3353031288059533942658390886683067124040920775575537747144343083137631628272);
        assertEq(result.y, 19321533766552368860946552437480515441416830039777911637913418824951667761761);
    }

    function test_multiScalarMul() public {
        BN254.G1Point memory point1 = BN254.G1Point(1, 2);
        BN254.G1Point memory point2 = BN254.G1Point(1, 2);
        BN254.G1Point memory point3 = BN254.G1Point(1, 2);
        BN254.G1Point memory point4 = BN254.G1Point(1, 2);
        uint256 scalar1 = 2;
        uint256 scalar2 = 2;
        uint256 scalar3 = 2;
        uint256 scalar4 = 2;

        BN254.G1Point[] memory bases = new BN254.G1Point[](4);
        bases[0] = point1;
        bases[1] = point2;
        bases[2] = point3;
        bases[3] = point4;

        uint256[] memory scalars = new uint256[](4);
        scalars[0] = scalar1;
        scalars[1] = scalar2;
        scalars[2] = scalar3;
        scalars[3] = scalar4;

        BN254.G1Point memory result = BN254.multiScalarMul(bases, scalars);
        assertEq(result.x, 3932705576657793550893430333273221375907985235130430286685735064194643946083);
        assertEq(result.y, 18813763293032256545937756946359266117037834559191913266454084342712532869153);
    }
}
