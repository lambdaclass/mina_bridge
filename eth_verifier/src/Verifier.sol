// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../lib/bn254/BN256G2.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Commitment.sol";
import "../lib/Oracles.sol";
import "../lib/Proof.sol";
import "../lib/State.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Constants.sol";
import "../lib/Alphas.sol";
import "../lib/Evaluations.sol";
import "../lib/deserialize/ProverProof.sol";
import "../lib/deserialize/PublicInputs.sol";
import "../lib/deserialize/VerifierIndex.sol";
import "../lib/deserialize/Linearization.sol";
import "../lib/expr/Expr.sol";
import "../lib/expr/PolishToken.sol";
import "../lib/expr/ExprConstants.sol";
import "./KimchiPartialVerifier.sol";

import "forge-std/console.sol";

using {BN254.add, BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {get_alphas} for Alphas;
using {it_next} for AlphasIterator;

contract KimchiVerifier {
    using {BN254.add, BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
    using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
    using {get_alphas} for Alphas;
    using {it_next} for AlphasIterator;
    using {Proof.get_column_eval} for Proof.ProofEvaluations;
    using {register} for Alphas;

    using {register} for Alphas;

    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);

    Proof.ProverProof proof;
    VerifierIndexLib.VerifierIndex verifier_index;
    Commitment.URS urs;

    Scalar.FE public_input;

    Proof.AggregatedEvaluationProof aggregated_proof;
    State internal state;
    bool state_available;

    Sponge base_sponge;
    Sponge scalar_sponge;

    bool last_verification_result;

    function setup() public {
        // Setup URS
        urs.g = new BN254.G1Point[](3);
        urs.g[0] = BN254.G1Point(1, 2);
        urs.g[1] = BN254.G1Point(
            0x0988F35DB6971FD77C8F9AFDAE27F7FB355577586DE4C517537D17882F9B3F34,
            0x23BAFFA63FAFC8C67007390A6E6DD52860B4A8AE95F49905D52CDB2C3B4CB203
        );
        urs.g[2] = BN254.G1Point(
            0x0D4B868BD01F4E7A548F7EB25B8804890153E13D05AB0783F4A9FABE91A4434A,
            0x054E363BD9AAF55F8354328C3D7D1E515665B0875BFAA639E3E654D291CF9BC6
        );
        urs.h = BN254.G1Point(
            0x259C9A9126385A54663D11F284944E91215DF44F4A502100B46BC91CCF373772,
            0x0EC1C952555B2D6978D2D39FA999D6469581ECF94F61262CDC9AA5C05FB8E70B
        );

        // INFO: powers of alpha are fixed for a given constraint system, so we can hard-code them.
        verifier_index.powers_of_alpha.register(ArgumentType.GateZero, VARBASEMUL_CONSTRAINTS);
        verifier_index.powers_of_alpha.register(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);

        // INFO: endo coefficient is fixed for a given constraint system
        (Base.FE _endo_q, Scalar.FE endo_r) = BN254.endo_coeffs_g1();
        verifier_index.endo = endo_r;
    }

    function store_verifier_index(bytes calldata data_serialized) public {
        deser_verifier_index(data_serialized, verifier_index);
    }

    function store_linearization(bytes calldata data_serialized) public {
        deser_linearization(data_serialized, verifier_index.linearization);
    }

    function store_prover_proof(bytes calldata data_serialized) public {
        deser_prover_proof(data_serialized, proof);
    }

    function store_public_input(bytes calldata data_serialized) public {
        public_input = deser_public_input(data_serialized);
    }

    function full_verify() public returns (bool) {
        Proof.AggregatedEvaluationProof memory agg_proof =
            KimchiPartialVerifier.partial_verify(proof, verifier_index, urs, public_input, base_sponge, scalar_sponge);
        return final_verify(agg_proof);
    }

    function partial_verify_and_store() public {
        aggregated_proof =
            KimchiPartialVerifier.partial_verify(proof, verifier_index, urs, public_input, base_sponge, scalar_sponge);
    }

    function final_verify_stored() public {
        last_verification_result = final_verify(aggregated_proof);
    }

    function is_last_proof_valid() public view returns (bool) {
        return last_verification_result;
    }

    function final_verify(Proof.AggregatedEvaluationProof memory agg_proof) public view returns (bool) {
        Evaluation[] memory evaluations = agg_proof.evaluations;
        Scalar.FE[2] memory evaluation_points = agg_proof.evaluation_points;
        Scalar.FE polyscale = agg_proof.polyscale;

        // poly commitment
        (BN254.G1Point memory poly_commitment, Scalar.FE[] memory evals) =
            Commitment.combine_commitments_and_evaluations(evaluations, polyscale, Scalar.one());

        // blinding commitment
        BN254.G1Point memory blinding_commitment = urs.h.scale_scalar(agg_proof.opening.blinding);

        // quotient commitment
        BN254.G1Point memory quotient = agg_proof.opening.quotient;

        // divisor commitment
        BN254.G2Point memory divisor = divisor_commitment(evaluation_points);

        // eval commitment
        BN254.G1Point memory eval_commitment = eval_commitment(evaluation_points, evals, urs);

        // numerator commitment
        BN254.G1Point memory numerator = poly_commitment.sub(eval_commitment.add(blinding_commitment));

        // quotient commitment needs to be negated. See the doc of pairingProd2().
        return BN254.pairingProd2(numerator, BN254.P2(), quotient.neg(), divisor);
    }

    function divisor_commitment(Scalar.FE[2] memory evaluation_points)
        public
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

        Scalar.FE[] memory divisor_poly_coeffs = new Scalar.FE[](2);

        // The divisor polynomial is the poly that evaluates to 0 in the evaluation
        // points. Used for proving that the numerator is divisible by it.
        // So, this is: (x-a)(x-b) = x^2 - (a + b)x + ab
        // (there're only two evaluation points: a and b).

        divisor_poly_coeffs[0] = evaluation_points[0].mul(evaluation_points[1]);
        divisor_poly_coeffs[1] = evaluation_points[0].add(evaluation_points[1]).neg();

        result = BN256G2.ECTwistMul(Scalar.FE.unwrap(divisor_poly_coeffs[0]), point0);
        result = BN256G2.ECTwistAdd(result, BN256G2.ECTwistMul(Scalar.FE.unwrap(divisor_poly_coeffs[1]), point1));
        result = BN256G2.ECTwistAdd(result, point2);
    }

    function eval_commitment(
        Scalar.FE[2] memory evaluation_points,
        Scalar.FE[] memory evals,
        Commitment.URS memory full_urs
    ) public view returns (BN254.G1Point memory) {
        Scalar.FE[] memory eval_poly_coeffs = new Scalar.FE[](3);

        // The evaluation polynomial e(x) is the poly that evaluates to evals[i]
        // in the evaluation point i, for all i. Used for making the numerator
        // evaluate to zero at the evaluation points (by substraction).

        require(evals.length == 2, "more than two evals");

        Scalar.FE x1 = evaluation_points[0];
        Scalar.FE x2 = evaluation_points[1];
        Scalar.FE y1 = evals[0];
        Scalar.FE y2 = evals[1];

        // So, this is: e(x) = ax + b, with:
        // a = (y2-y1)/(x2-x1)
        // b = y1 - a*x1

        Scalar.FE a = (y2.sub(y1)).mul(x2.sub(x1).inv());
        Scalar.FE b = y1.sub(a.mul(x1));

        eval_poly_coeffs[0] = b;
        eval_poly_coeffs[1] = a;

        return Commitment.msm(full_urs.g, eval_poly_coeffs);
    }
}
