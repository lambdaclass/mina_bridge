// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Base} from "../lib/bn254/Fields.sol";
import {BN254} from "../lib/bn254/BN254.sol";
import {BN256G2} from "../lib/bn254/BN256G2.sol";
import {Scalar} from "../lib/VerifierIndex.sol";
import {Proof} from "../lib/Proof.sol";
import {Commitment} from "../lib/Commitment.sol";
import {Evaluation} from "../lib/Evaluations.sol";
import {VARBASEMUL_CONSTRAINTS, PERMUTATION_CONSTRAINTS} from "../lib/Constants.sol";
import {ArgumentType, Alphas, AlphasIterator, get_alphas, register, it_next} from "../lib/Alphas.sol";
import {deser_prover_proof} from "../lib/deserialize/ProverProof.sol";
import {deser_proof_hash} from "../lib/deserialize/PublicInputs.sol";
import {deser_verifier_index, VerifierIndexLib} from "../lib/deserialize/VerifierIndex.sol";
import {deser_linearization, deser_literal_tokens} from "../lib/deserialize/Linearization.sol";
import {deser_merkle_path} from "../lib/deserialize/MerkleProof.sol";
import {KimchiPartialVerifier} from "./KimchiPartialVerifier.sol";
import {Pasta} from "../lib/pasta/Fields.sol";
import {MerkleVerifier} from "../lib/merkle/Verify.sol";
import {Poseidon} from "../lib/poseidon/Pasta.sol";

contract KimchiVerifier {
    uint256 internal constant G2_X0 = 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2;
    uint256 internal constant G2_X1 = 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed;
    uint256 internal constant G2_Y0 = 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b;
    uint256 internal constant G2_Y1 = 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa;

    using {get_alphas, register} for Alphas;
    using {it_next} for AlphasIterator;

    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);
    error MoreThanTwoEvals(); // more than two evals
    error PairingCheckFailed(); // Bn254: pairing check failed!

    Proof.ProverProof internal proof;
    VerifierIndexLib.VerifierIndex internal verifier_index;
    Commitment.URS internal urs;

    uint256 internal proof_hash;

    Proof.AggregatedEvaluationProof internal aggregated_proof;

    bool internal last_verification_result;

    MerkleVerifier merkle_verifier = new MerkleVerifier();
    Poseidon poseidon = new Poseidon();
    Pasta.Fp internal potential_merkle_root;
    Pasta.Fp internal merkle_root = Pasta.from(0);

    function setup() public {
        // Setup URS
        urs.g = new BN254.G1Point[](2);
        urs.g[0] = BN254.G1Point(1, 2);
        urs.g[1] = BN254.G1Point(
            0x0988F35DB6971FD77C8F9AFDAE27F7FB355577586DE4C517537D17882F9B3F34,
            0x23BAFFA63FAFC8C67007390A6E6DD52860B4A8AE95F49905D52CDB2C3B4CB203
        );
        urs.h = BN254.G1Point(
            0x259C9A9126385A54663D11F284944E91215DF44F4A502100B46BC91CCF373772,
            0x0EC1C952555B2D6978D2D39FA999D6469581ECF94F61262CDC9AA5C05FB8E70B
        );

        // INFO: powers of alpha are fixed for a given constraint system, so we can hard-code them.
        verifier_index.powers_of_alpha.register(ArgumentType.GateZero, VARBASEMUL_CONSTRAINTS);
        verifier_index.powers_of_alpha.register(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);

        // INFO: endo coefficient is fixed for a given constraint system
        (uint256 _endo_q, uint256 endo_r) = BN254.endo_coeffs_g1();
        verifier_index.endo = endo_r;
    }

    function store_verifier_index(bytes calldata data_serialized) public {
        deser_verifier_index(data_serialized, verifier_index);
    }

    function store_linearization(bytes calldata data_serialized) public {
        deser_linearization(data_serialized, verifier_index.linearization);
    }

    function store_literal_tokens(bytes calldata data_serialized) public {
        deser_literal_tokens(data_serialized, verifier_index.linearization);
    }

    function store_prover_proof(bytes calldata data_serialized) public {
        deser_prover_proof(data_serialized, proof);
    }

    function store_proof_hash(bytes calldata data_serialized) public {
        proof_hash = deser_proof_hash(data_serialized);
    }

    function store_potential_merkle_root(bytes calldata data_serialized) public {
        potential_merkle_root = Pasta.from(uint256(bytes32(data_serialized)));
    }

    function verify_account_inclusion(bytes32 leaf_hash_bytes, bytes calldata path_serialized) public view returns (bool) {
        if (Pasta.Fp.unwrap(merkle_root) == 0) {
            revert("the merkle root is missing, verify a state before calling this.");
        }
 
        Pasta.Fp leaf_hash = Pasta.from(uint256(leaf_hash_bytes));
        MerkleVerifier.PathElement[] memory merkle_path = deser_merkle_path(path_serialized);

        Pasta.Fp calculated_root = merkle_verifier.calc_path_root(merkle_path, leaf_hash, poseidon);
        return Pasta.Fp.unwrap(calculated_root) == Pasta.Fp.unwrap(merkle_root);
    }

    function full_verify() public returns (bool) {
        Proof.AggregatedEvaluationProof memory agg_proof =
            KimchiPartialVerifier.partial_verify(proof, verifier_index, urs, proof_hash, Pasta.Fp.unwrap(potential_merkle_root));
        return final_verify(agg_proof);
    }

    function partial_verify_and_store() public {
        aggregated_proof = KimchiPartialVerifier.partial_verify(proof, verifier_index, urs, proof_hash, Pasta.Fp.unwrap(potential_merkle_root));
    }

    function final_verify_and_store() public {
        last_verification_result = final_verify(aggregated_proof);
    }

    function is_last_proof_valid() public view returns (bool) {
        return last_verification_result;
    }

    function final_verify(Proof.AggregatedEvaluationProof memory agg_proof) public returns (bool) {
        Evaluation[] memory evaluations = agg_proof.evaluations;
        uint256[2] memory evaluation_points = agg_proof.evaluation_points;
        uint256 polyscale = agg_proof.polyscale;

        // poly commitment
        (BN254.G1Point memory poly_commitment, uint256[] memory evals) =
            Commitment.combine_commitments_and_evaluations(evaluations, polyscale, 1);

        // blinding commitment
        BN254.G1Point memory blinding_commitment = BN254.scalarMul(urs.h, agg_proof.opening.blinding);

        // quotient commitment
        BN254.G1Point memory quotient = agg_proof.opening.quotient;

        // divisor commitment
        BN254.G2Point memory divisor = divisor_commitment(evaluation_points);

        // eval commitment
        // numerator commitment
        BN254.G1Point memory numerator =
            BN254.sub(poly_commitment, BN254.add(eval_commitment(evaluation_points, evals, urs), blinding_commitment));

        uint256 out;
        bool success;
        // quotient commitment needs to be negated. See the doc of pairingProd2().
        quotient = BN254.neg(quotient);

        assembly ("memory-safe") {
            let mPtr := mload(0x40)
            mstore(mPtr, mload(numerator))
            mstore(add(mPtr, 0x20), mload(add(numerator, 0x20)))

            mstore(add(mPtr, 0x40), G2_X0)
            mstore(add(mPtr, 0x60), G2_X1)
            mstore(add(mPtr, 0x80), G2_Y0)
            mstore(add(mPtr, 0xa0), G2_Y1)

            mstore(add(mPtr, 0xc0), mload(quotient))
            mstore(add(mPtr, 0xe0), mload(add(quotient, 0x20)))
            mstore(add(mPtr, 0x100), mload(divisor))
            mstore(add(mPtr, 0x120), mload(add(divisor, 0x20)))
            mstore(add(mPtr, 0x140), mload(add(divisor, 0x40)))
            mstore(add(mPtr, 0x160), mload(add(divisor, 0x60)))
            success := staticcall(gas(), 8, mPtr, 0x180, 0x00, 0x20)
            out := mload(0x00)
        }
        if (!success) {
            revert PairingCheckFailed();
        }

        if (out != 0) {
            // save "verified" merkle root (we would need a way to check that the potential merkle
            // root corresponds to the verified proof).
            merkle_root = potential_merkle_root;
            return true;
        }
    }

    function divisor_commitment(uint256[2] memory evaluation_points)
        internal
        view
        returns (BN254.G2Point memory result)
    {
        BN254.G2Point memory point0 = BN254.G2Point(
            10857046999023057135944570762232829481370756359578518086990519993285655852781,
            11559732032986387107991004021392285783925812861821192530917403151452391805634,
            8495653923123431417604973247489272438418190587263600148770280649306958101930,
            4082367875863433681332203403145435568316851327593401208105741076214120093531
        );
        BN254.G2Point memory point1 = BN254.G2Point(
            7883069657575422103991939149663123175414599384626279795595310520790051448551,
            8346649071297262948544714173736482699128410021416543801035997871711276407441,
            3343323372806643151863786479815504460125163176086666838570580800830972412274,
            16795962876692295166012804782785252840345796645199573986777498170046508450267
        );
        BN254.G2Point memory point2 = BN254.G2Point(
            4640749047686948693676466477499634979423220823002391841311260833878642348023,
            14127762918448947308790410788210289377279518096121173062251311797297982082469,
            13424649497566617342906600132389867025763662606076913038585301943152028890013,
            15584633174679797224858067860955702731818107814729714298421481259259086801380
        );

        uint256[] memory divisor_poly_coeffs = new uint256[](2);

        // The divisor polynomial is the poly that evaluates to 0 in the evaluation
        // points. Used for proving that the numerator is divisible by it.
        // So, this is: (x-a)(x-b) = x^2 - (a + b)x + ab
        // (there're only two evaluation points: a and b).

        divisor_poly_coeffs[0] = Scalar.mul(evaluation_points[0], evaluation_points[1]);
        divisor_poly_coeffs[1] = Scalar.neg(Scalar.add(evaluation_points[0], evaluation_points[1]));

        result = BN256G2.ECTwistMul(divisor_poly_coeffs[0], point0);
        result = BN256G2.ECTwistAdd(result, BN256G2.ECTwistMul(divisor_poly_coeffs[1], point1));
        result = BN256G2.ECTwistAdd(result, point2);
    }

    function eval_commitment(
        uint256[2] memory evaluation_points,
        uint256[] memory evals,
        Commitment.URS memory full_urs
    ) internal view returns (BN254.G1Point memory) {
        uint256[] memory eval_poly_coeffs = new uint256[](2);

        // The evaluation polynomial e(x) is the poly that evaluates to evals[i]
        // in the evaluation point i, for all i. Used for making the numerator
        // evaluate to zero at the evaluation points (by substraction).

        if (evals.length > 2) revert MoreThanTwoEvals();

        uint256 x1 = evaluation_points[0];
        uint256 x2 = evaluation_points[1];
        uint256 y1 = evals[0];
        uint256 y2 = evals[1];

        // So, this is: e(x) = ax + b, with:
        // a = (y2-y1)/(x2-x1)
        // b = y1 - a*x1

        uint256 a = Scalar.mul(Scalar.sub(y2, y1), Scalar.inv(Scalar.sub(x2, x1)));
        uint256 b = Scalar.sub(y1, Scalar.mul(a, x1));

        eval_poly_coeffs[0] = b;
        eval_poly_coeffs[1] = a;

        return BN254.multiScalarMul(full_urs.g, eval_poly_coeffs);
    }
}
