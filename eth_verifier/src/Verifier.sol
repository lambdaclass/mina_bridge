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

using {BN254.add, BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {get_alphas} for Alphas;
using {it_next} for AlphasIterator;
using {sub_polycomms, scale_polycomm} for PolyComm;

contract KimchiVerifier {
    using {BN254.add, BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
    using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
    using {get_alphas} for Alphas;
    using {it_next} for AlphasIterator;
    using {sub_polycomms, scale_polycomm} for PolyComm;
    using {get_column_eval} for ProofEvaluations;
    using {register} for Alphas;

    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);

    ProverProof proof;
    VerifierIndex verifier_index;
    URS urs;
    Scalar.FE[222] public_inputs;

    Sponge base_sponge;
    Sponge scalar_sponge;

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

    function deserialize_proof(
        bytes calldata verifier_index_serialized,
        bytes calldata prover_proof_serialized,
        bytes calldata linearization_serialized,
        bytes calldata public_inputs_serialized
    ) public {
        deser_verifier_index(verifier_index_serialized, verifier_index);
        deser_prover_proof(prover_proof_serialized, proof);
        deser_linearization(linearization_serialized, verifier_index.linearization);
        deser_public_inputs(public_inputs_serialized, public_inputs);
    }

    function verify_with_index(
        bytes calldata verifier_index_serialized,
        bytes calldata prover_proof_serialized,
        bytes calldata linearization_serialized_rlp,
        bytes calldata public_inputs_serialized
    ) public returns (bool) {
        deserialize_proof(
            verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp, public_inputs_serialized
        );
        AggregatedEvaluationProof memory agg_proof = partial_verify();
        return final_verify(agg_proof);
    }

    // This takes Kimchi's `to_batch()` as reference.
    function partial_verify() public returns (AggregatedEvaluationProof memory) {
        // TODO: 1. CHeck the length of evaluations insde the proof

        // 2. Commit to the negated public input polynomial.
        BN254.G1Point memory public_comm = public_commitment();

        // 3. Execute fiat-shamir with a Keccak sponge

        Oracles.Result memory oracles_res =
            Oracles.fiat_shamir(proof, verifier_index, public_comm, public_inputs, true, base_sponge, scalar_sponge);
        Oracles.RandomOracles memory oracles = oracles_res.oracles;

        // 4. Combine the chunked polynomials' evaluations

        //ProofEvaluations memory evals = proof.evals.combine_evals(oracles_res.powers_of_eval_points_for_chunks);
        // INFO: There's only one evaluation per polynomial so there's nothing to combine
        ProofEvaluations memory evals = proof.evals;

        // 5. Compute the commitment to the linearized polynomial $f$.
        Scalar.FE permutation_vanishing_polynomial = Polynomial.eval_vanishes_on_last_n_rows(
            verifier_index.domain_gen, verifier_index.domain_size, verifier_index.zk_rows, oracles.zeta
        );

        AlphasIterator memory alphas =
            verifier_index.powers_of_alpha.get_alphas(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);

        BN254.G1Point[] memory commitments = new BN254.G1Point[](1);
        commitments[0] = verifier_index.sigma_comm[PERMUTS - 1];
        Scalar.FE[] memory scalars = new Scalar.FE[](1);
        scalars[0] = perm_scalars(evals, oracles.beta, oracles.gamma, alphas, permutation_vanishing_polynomial);

        BN254.G1Point memory f_comm = msm(commitments, scalars);

        // 6. Compute the chunked commitment of ft
        Scalar.FE zeta_to_srs_len = oracles.zeta.pow(verifier_index.max_poly_size);
        BN254.G1Point memory chunked_f_comm = f_comm;

        BN254.G1Point[7] memory t_comm = proof.commitments.t_comm;
        BN254.G1Point memory chunked_t_comm = BN254.point_at_inf();

        for (uint256 i = 0; i < t_comm.length; i++) {
            chunked_t_comm = chunked_t_comm.scale_scalar(zeta_to_srs_len);
            chunked_t_comm = chunked_t_comm.add(t_comm[t_comm.length - i - 1]);
        }

        BN254.G1Point memory ft_comm =
            chunked_f_comm.sub(chunked_t_comm.scale_scalar(oracles_res.zeta1.sub(Scalar.one())));

        // 7. List the polynomial commitments, and their associated evaluations,
        // that are associated to the aggregated evaluation proof in the proof:

        uint256 evaluations_len = 56; // INFO: hard-coded for the test proof
        Evaluation[] memory evaluations = new Evaluation[](evaluations_len);

        uint256 eval_index = 0;

        // public input commitment
        evaluations[eval_index++] = Evaluation(public_comm, oracles_res.public_evals, 0);

        // ft commitment
        evaluations[eval_index++] = Evaluation(ft_comm, [oracles_res.ft_eval0, proof.ft_eval1], 0);
        uint256 columns_len = 52; // INFO: hard-coded for the test proof
        Column[] memory columns = new Column[](columns_len);
        columns[0] = Column(ColumnVariant.Z, new bytes(0));
        columns[1] = Column(ColumnVariant.Index, abi.encode(GateType.Generic));
        columns[2] = Column(ColumnVariant.Index, abi.encode(GateType.Poseidon));
        columns[3] = Column(ColumnVariant.Index, abi.encode(GateType.CompleteAdd));
        columns[4] = Column(ColumnVariant.Index, abi.encode(GateType.VarBaseMul));
        columns[5] = Column(ColumnVariant.Index, abi.encode(GateType.EndoMul));
        columns[6] = Column(ColumnVariant.Index, abi.encode(GateType.EndoMulScalar));
        uint256 col_index = 7;
        for (uint256 i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Witness, abi.encode(i));
        }
        for (uint256 i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Coefficient, abi.encode(i));
        }
        for (uint256 i = 0; i < PERMUTS - 1; i++) {
            columns[col_index++] = Column(ColumnVariant.Permutation, abi.encode(i));
        }
        if (is_field_set(verifier_index, RANGE_CHECK0_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck0));
        }
        if (is_field_set(verifier_index, RANGE_CHECK1_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck1));
        }
        if (is_field_set(verifier_index, FOREIGN_FIELD_ADD_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldAdd));
        }
        if (is_field_set(verifier_index, FOREIGN_FIELD_MUL_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldMul));
        }
        if (is_field_set(verifier_index, XOR_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.Xor16));
        }
        if (is_field_set(verifier_index, ROT_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.Rot64));
        }
        if (is_field_set(verifier_index, LOOKUP_VERIFIER_INDEX_FLAG)) {
            LookupVerifierIndex memory li = verifier_index.lookup_index;
            for (uint256 i = 0; i < li.lookup_info.max_per_row + 1; i++) {
                columns[col_index++] = Column(ColumnVariant.LookupSorted, abi.encode(i));
            }
            columns[col_index++] = Column(ColumnVariant.LookupAggreg, new bytes(0));
        }
        // push all commitments corresponding to each column
        for (uint256 i = 0; i < col_index; i++) {
            PointEvaluations memory eval = get_column_eval(proof.evals, columns[i]);
            evaluations[eval_index++] =
                Evaluation(get_column_commitment(verifier_index, proof, columns[i]), [eval.zeta, eval.zeta_omega], 0);
        }

        if (is_field_set(verifier_index, LOOKUP_VERIFIER_INDEX_FLAG)) {
            LookupVerifierIndex memory li = verifier_index.lookup_index;
            if (!is_field_set(proof.commitments, LOOKUP_SORTED_COMM_FLAG)) {
                revert("missing lookup commitments"); // TODO: error
            }
            PointEvaluations memory lookup_evals = proof.evals.lookup_table;
            if (!is_field_set(proof.evals, LOOKUP_TABLE_EVAL_FLAG)) {
                revert("missing lookup table eval");
            }
            PointEvaluations memory lookup_table = proof.evals.lookup_table;

            Scalar.FE joint_combiner = oracles.joint_combiner_field;
            Scalar.FE table_id_combiner = joint_combiner.pow(li.lookup_info.max_joint_size);

            BN254.G1Point memory table_comm = combine_table(
                li.lookup_table,
                joint_combiner,
                table_id_combiner,
                is_field_set(li, TABLE_IDS_FLAG),
                li.table_ids,
                is_field_set(proof.commitments, LOOKUP_RUNTIME_COMM_FLAG),
                proof.commitments.lookup_runtime
            );

            evaluations[eval_index++] =
                Evaluation(table_comm, [lookup_table.zeta, lookup_table.zeta_omega], 0);

            if (is_field_set(li, RUNTIME_TABLES_SELECTOR_FLAG)) {
                if (!is_field_set(proof.commitments, LOOKUP_RUNTIME_COMM_FLAG)) {
                    revert("missing lookup runtime commitment");
                }
                BN254.G1Point memory runtime = proof.commitments.lookup_runtime;
                if (!is_field_set(proof.evals, RUNTIME_LOOKUP_TABLE_EVAL_FLAG)) {
                    revert("missing runtime lookup table eval");
                }
                PointEvaluations memory runtime_eval = proof.evals.runtime_lookup_table;

                evaluations[eval_index++] = Evaluation(runtime, [runtime_eval.zeta, runtime_eval.zeta_omega], 0);
            }

            if (is_field_set(li, RUNTIME_TABLES_SELECTOR_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupRuntimeSelector, new bytes(0));
                PointEvaluations memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] =
                    Evaluation(get_column_commitment(verifier_index, proof, col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, XOR_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Xor));
                PointEvaluations memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] =
                    Evaluation(get_column_commitment(verifier_index, proof, col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, LOOKUP_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Lookup));
                PointEvaluations memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] =
                    Evaluation(get_column_commitment(verifier_index, proof, col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, RANGE_CHECK_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.RangeCheck));
                PointEvaluations memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] =
                    Evaluation(get_column_commitment(verifier_index, proof, col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, FFMUL_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.ForeignFieldMul));
                PointEvaluations memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] =
                    Evaluation(get_column_commitment(verifier_index, proof, col), [eval.zeta, eval.zeta_omega], 0);
            }
        }

        Scalar.FE[2] memory evaluation_points = [oracles.zeta, oracles.zeta.mul(verifier_index.domain_gen)];

        return AggregatedEvaluationProof(evaluations, evaluation_points, oracles.v, proof.opening);
    }

    function public_commitment() public view returns (BN254.G1Point memory) {
        if (verifier_index.domain_size < verifier_index.max_poly_size) {
            revert PolynomialsAreChunked(verifier_index.domain_size / verifier_index.max_poly_size);
        }

        if (public_inputs.length != verifier_index.public_len) {
            revert IncorrectPublicInputLength();
        }
        BN254.G1Point memory public_comm;
        if (public_inputs.length == 0) {
            public_comm = urs.h;
        } else {
            public_comm = BN254.point_at_inf();
            for (uint256 i = 0; i < public_inputs.length; i++) {
                public_comm = public_comm.add(get_lagrange_base(i).scale_scalar(public_inputs[i]));
            }
            // negate the results of the MSM
            public_comm = public_comm.neg();

            public_comm = urs.h.add(public_comm);
        }

        return public_comm;
    }

    function perm_scalars(
        ProofEvaluations memory e,
        Scalar.FE beta,
        Scalar.FE gamma,
        AlphasIterator memory alphas,
        Scalar.FE zkp_zeta
    ) internal view returns (Scalar.FE res) {
        require(alphas.powers.length - alphas.current_index == 3, "not enough powers of alpha for permutation");

        Scalar.FE alpha0 = alphas.it_next();
        Scalar.FE _alpha1 = alphas.it_next();
        Scalar.FE _alpha2 = alphas.it_next();

        res = e.z.zeta_omega.mul(beta).mul(alpha0).mul(zkp_zeta);
        uint256 len = Utils.min(e.w.length, e.s.length);
        for (uint256 i = 0; i < len; i++) {
            Scalar.FE current = gamma.add(beta.mul(e.s[i].zeta)).add(e.w[i].zeta);
            res = res.mul(current);
        }
        res = res.neg();
    }

    /*
    This is a list of steps needed for verification.

    Partial verification:
        1. Check the length of evaluations insde the proof.
        2. Commit to the negated public input poly
        3. Fiat-Shamir (vastly simplify for now)
        4. Combined chunk polynomials evaluations
        5. Commitment to linearized polynomial f
        6. Chunked commitment of ft
        7. List poly commitments for final verification

    Final verification:
        1. Combine commitments, compute final poly commitment (MSM)
        2. Combine evals
        3. Commit divisor and eval polynomials
        4. Compute numerator commitment
        5. Compute scaled quotient
        6. Check numerator == scaled_quotient
    */

    function final_verify(AggregatedEvaluationProof memory agg_proof) public view returns (bool) {
        Evaluation[] memory evaluations = agg_proof.evaluations;
        Scalar.FE[2] memory evaluation_points = agg_proof.evaluation_points;
        Scalar.FE polyscale = agg_proof.polyscale;

        // poly commitment
        (BN254.G1Point memory poly_commitment, Scalar.FE[] memory evals) =
            combine_commitments_and_evaluations(evaluations, polyscale, Scalar.one());

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
            14127762918448947308790410788210289377279518096121173062251311797297982082469,
            4640749047686948693676466477499634979423220823002391841311260833878642348023,
            15584633174679797224858067860955702731818107814729714298421481259259086801380,
            13424649497566617342906600132389867025763662606076913038585301943152028890013
        );

        Scalar.FE[] memory divisor_poly_coeffs = new Scalar.FE[](3);

        // The divisor polynomial is the poly that evaluates to 0 in the evaluation
        // points. Used for proving that the numerator is divisible by it.
        // So, this is: (x-a)(x-b) = x^2 - (a + b)x + ab
        // (there're only two evaluation points: a and b).

        divisor_poly_coeffs[0] = evaluation_points[0].mul(evaluation_points[1]);
        divisor_poly_coeffs[1] = evaluation_points[0].add(evaluation_points[1]).neg();
        divisor_poly_coeffs[2] = Scalar.one();

        result = BN256G2.ECTwistMul(Scalar.FE.unwrap(divisor_poly_coeffs[0]), point0);
        result = BN256G2.ECTwistAdd(result, BN256G2.ECTwistMul(Scalar.FE.unwrap(divisor_poly_coeffs[1]), point1));
        result = BN256G2.ECTwistAdd(result, BN256G2.ECTwistMul(Scalar.FE.unwrap(divisor_poly_coeffs[2]), point2));
    }

    function eval_commitment(Scalar.FE[2] memory evaluation_points, Scalar.FE[] memory evals, URS memory full_urs)
        public
        view
        returns (BN254.G1Point memory)
    {
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

        return msm(full_urs.g, eval_poly_coeffs);
    }

    // (x, y) pairs
    uint256[444] lagrange_bases = [
        0x280c10e2f52fb4ab3ba21204b30df5b69560978e0911a5c673ad0558070f17c1,
        0x287897da7c8db33cd988a1328770890b2754155612290448267f9ca4c549cb39,
        0x0b35633d832d4d9f7eba915557958008c10eb77f2f0d8229f0d35b1f6727b3e0,
        0x12797f9857171467fffa845854dee787f76f8e6f84dc905d44dbf1a38282fde6,
        0x04ad02e8adf9100cc71684755f19eeb9608783afda9afbbe18c0393af28e140d,
        0x2f70312db0f90936954edd3f59f9eecc4ac8a185a768511e1c2269aabb8a7c99,
        0x271766293d02edfff8434c46585e86f3c19583e7cf9c705132f2319078d17f54,
        0x092c0f673d87d22ae4db6dd8a274772fff359f875f1264a1fa0187ce22053931,
        0x02c8d86c838f0f1b55aafbc673b773019846427f0e01cfa2be0935013c715d02,
        0x1d624d98b43da309ff45aac457fd494c6c80b997b596ca77bc1c2a80cb2a031b,
        0x27c52b0a95a56de35271f7264403a6de81ce55d2cf230918dbebeffef32fe616,
        0x02a0f959cdbe8b91b1bcde12c6620bff1315ed73cc816a3e5883b81882d44cf1,
        0x276be2fc3702f4e949e23e27ec2dc690f69484281370cf6dddfd2b35f5f1e26a,
        0x0ba5adc27ec5b0a3062e8072a0b6084553ed816b02d002298bb5ae8322cc516b,
        0x0568f61c26e436c23841663d09ef6c6f846a7240396885d4b9b0881d2bd76d8e,
        0x26c3429a60200dc4789a21b7b8d229a637b6e48c2b83f81f20de82879cf034f7,
        0x1415ef3ab36e25d70022aff521924902728d9d4e85f9582263fce1bf7d2250f9,
        0x2450d39e546ce79628f8b7ed88d4cba391126b86d36198c682f8480a91a74cdf,
        0x053afbe53799c6a160f3c7939385bdfba27400ce5f419831f0f1f77ac1c8057a,
        0x1f1c797e23a026cbc4f171facf2678b54e9b6e04f7787db2f69dc4dbb78f9216,
        0x2e75c424744020262cd2b455579cbccc499b74fe7234bdbd1aea8b032b5e2b26,
        0x29e5de9b3e9ae5aeac7228b80b94b8846236b48263cff55b6de098ecc9477342,
        0x0761f2817bd0b4cdc27926a71578dd7e6e2784f959929a735b0f0be270ccf1bd,
        0x2b03680ded90ad4ab1b635b9e964618f394e21af353e362e1a22586b290127da,
        0x076a11f7adad8c85b46a84c14475a5267114baddf18f668422c1b0c879968940,
        0x00dd2c4490fcf02139e44b89366746b90f3c5b3dbc9e72d66d2a9d7e21cf50ae,
        0x2e5679683713053be9a1bfb090e58979b031e46cdc22dd87f67ed30812ba2cde,
        0x24e5e038ca2f61f40dffffd2875005ddf06e67968a8cc82f66e93a26b1386b2a,
        0x16dcf147773d680ab9badada9a080c61f0aca1545e9b119641397e55caf605c4,
        0x1ad7e83da0c481d94e44cbe06ab98a0ef83cf783f3922cea0ef5998e472c9f53,
        0x12c71038092013ff6bd28166b39414f932884927f34cdde753fb75450fb4f887,
        0x28c3bff7d03ff7b47d606c7012fce237c781cb53c46cb0a0818ee02fac0b7f9d,
        0x11f468453cd9f8d0d975f54d1ca0f1cf607f20635ca4ecdfdf89f7ef69134ec9,
        0x21bd4409c98533a8e4084c113d492f86d51e3a032e999b256c3abd60d9bf35e6,
        0x2425b2e2af4a4ed32bf46ab8eeb6bbbc260f245937be5120376124b9904e8361,
        0x0253beac14d5fa6154f368e5dba09a84afa88897e3def6b0a8cd7f49534c7ea2,
        0x053e2938e2867fc95e600c8e5044e261d80c3b4a809458d8cebc89441a486784,
        0x2dadf5b72aa2f3274d9fe6d75a63d269a686a1618836d416c645c04785a82064,
        0x1e39f1421fd52b1a49001c723218b75b7bab717d6cfd3166ae6b055581ab95f1,
        0x1e193f74813f67ab490f6b4fb6f0c3dba94dfe96343dd7613ffff8fbdf70f963,
        0x0d65d9c0a34a6daace7fa20d6cda795ee2509ccdb1b4543829bd1995c5f5f84c,
        0x2a73659a3509dd49751bcc715fe890a692fe01c065f2e6990d842cf80736ed17,
        0x25f25479053a752fbfe81e136db719e614ca20e26134e70cc8069ee60a0b06b8,
        0x122164e252b1750ccf4352d592ab6d9e5ae20d1b5d13928b11113474c078fad6,
        0x26a3fedcf7bcf6d22b9fabe4bd8ab4f18e09f1150a741d2b460fd13823e0f3fa,
        0x11a5e2a432bce56873a2ee997ec42fae6b321994ce8676b7d5b221ab5ad43388,
        0x030e2057b6c447ce083b102ed010420606b988e617cd8ab7ab58e2c0a8fdde1a,
        0x03bff6bd98fbb5be7ede08407386c5df9f5a0bca5a4244eb2c2149807dd7d3b1,
        0x2057b36cf35b11eadb81b17332424ca6ea71932fdab6d85dbe2978a472ef96b7,
        0x2584783f50453707d356437333b3a20d144444fd32fa7d12b8e9a28f96edb478,
        0x1f3faf4e9658f08e54fa7f673900076e3c79c7adeec88b7a4140bd8cd5853210,
        0x270d957c87fa103c6b09a25586e91253937322306c0387f377f99f15cc2faaf7,
        0x291d8bddffd637f134418bc548cac77fec194ba50af6e0f830c2edd3966ead03,
        0x04a2d902945e46ff51bc91152a876a3c91dd28e5fd37d64890abc01697ba4dc3,
        0x174fb8362dde006c124d27597b502bfd2afa720d64b3b274f1d497b4c4ab544d,
        0x2ccb199af752904f8b705ec66ec7f6b57ff2b09f2d48d186392f153d964af4f3,
        0x0fc73b2c85b9003989c1eb632039e8896299651b55b9d3f7c22be743678b2e3a,
        0x2e9ad2b7114b3ee63223d02defc584a6f262f882ec7b61666c9e84d07d075d87,
        0x0e6d3a168c8fde835967cddf0dae70e0903b3a0d89e9dc3ba49b441654f6ea6e,
        0x2351edc48f1240e8f7b9374fd30cfae08cedd349063849cca70a00a9e0f55dcb,
        0x1bfd8e2a9aa0e0988a3a6f176bbb3a12a17a867a26360b8186229e56b87cb829,
        0x20bfe79e8fbcf858d2f61fe08f43106f4b4beefaca4e7f43e317f942fc94e1f5,
        0x05d143832d5a51f4e089df33ffb40f454e8190aeb6b5eee9e9201ee8c014af18,
        0x1b3302206f4effbfba676d4f3a53da6bab1737399119c26eb9010625c66fb1d2,
        0x11c106a107995a130224f0b6c36fd5ebe762c9f71023db6e2fdfb17243727e68,
        0x00dd911f33e13cade5fe8df0d6b94d1ea255f365e886cc5a2e336e4ad9882dab,
        0x1db8329775754b57d2115959120c9da4c1b3d483fe1ab9782fd2aa30962fc0b6,
        0x05eab078f9ad588817aa72a0713543c7d21b5462458da14bff4ced9dee4254fe,
        0x0f2fbded6963a5a2625c8d8dbbd638a7885f5a27efb2d130d6adab890bb07bba,
        0x2882e35a48271ddc1e489fae00a8b2ebe10b0e4c71ec490e599ea3069f04abe4,
        0x024656a7b7782894f53252f88b9fe79e45e23d93f7b0d7a339669947a640b4b8,
        0x1d844bd43b6fc6a921fe06b8e1caac0f6a70bc712f01ea909a6408f4f03368bf,
        0x20a899556b22d6b002512810cfd4db69e3d7bb96c97edeaa8f5a9e34f73180ed,
        0x225ba3e9af0d2753ca77d37848700fcee5ea96b88a707ee5482668daf49a8516,
        0x2fc93be5919e768542b52f9293ef40ad31c16ca163486dca1b831cfd93330700,
        0x05c519f5f8b5ca27e4391e07c61f50d43346659d660dd81b2f32bf64c9e6013a,
        0x2a750e84c0959537afd0d2058e7e34b09e6bdbab086de27c406c7fff7d4e09fb,
        0x29e1aa8bceb9437688c5b60dbee7c27134983f7e7c9754a5f4226a41f1761dd3,
        0x2581fd70afe609b219e6d00ac70fe7d68735daeb4ed35d3d2298d75714a26613,
        0x07e28578ec0938602064f60f92f0bcd13299a48fcbbc0d877df3f9f1dc9ae702,
        0x12a686d6fce4f27b23714a379f57e1fa239e83db2205aa1fb5e49eb3d4f4c370,
        0x26d20c6127c72c99dd14855471631d3c858938a4efabe72c86887faf28d9201e,
        0x0bb5fb5915f039033776b5908f589f00ca2c3da250fd15eec2a11ee98324443d,
        0x173f7c76f9989859b8b1ad5f4a2d8c96f3c627dffa74346c6c6c7a149c7a3744,
        0x054663b982ecc976b841b1996a10ce86cc6fed5a8d6322aa74f2c4c3da8ed6cc,
        0x09f5cb23e080fbff892b10224633c7606e38b872e8affd959c2d1c33e5a9d8a3,
        0x2814585c51803264a04e15ef6d080a42466d32be8eef984f07b594630990975d,
        0x0b88b2b61017b5a77a2ecf429159707b840d849afd010a5112f18db16cce4f7b,
        0x201eedf3e6c69c8622e2234b0f3292591ef1cd527deef0bda609bd32bf5fc539,
        0x0a9d103136d9293a5132e649de097bc2ffc15f836d6e7f807b68bbdc3ef78981,
        0x20b219cccbf74b0be063e8f196b9c4fbb9985cad7e113aacb802d34f51e4355e,
        0x12061149dc8aef0dce2261d487e2b84fa4ea2bdec7df116c162558526c3f28f1,
        0x0abdeb6f97a1cbeca3f33cd7811276988e231f4fcc7443fe0e40a682b6e4284e,
        0x06204e59e539052fa888e3a051fc13d712082e1eb6b94b2cecdf9be897b2fa5f,
        0x00b56f9082027157a241705b82f7de6951727ad3625c2f09f573166fb1f9ba9a,
        0x1b85db49542bfbddd037a0b75541c8bcfcb7d979b17135e6d485a097da526e07,
        0x0dd8c0b6cb3894bf4ad3e4b7d4f1dc814be7b7457eb120567be78c1f20a0d72c,
        0x172d78c09f0cda9a1da893fd0e6e14fdcb78936ae75032aa55f06358ee015dcb,
        0x09935999fd05bab813395d0741361410401a2bb600c4d01e79fdc926ecea7894,
        0x108ffb6b47266cf79d524aef791316558cc18293b07ca7ae981791a7ed29d3a5,
        0x0ee210cd4fe292e11d56d99905779ec03642e3d9d324254f210e30000735e266,
        0x0db1d54d185b0edd5d06de96986b49c370d259af97a25fd77efa045046866b69,
        0x1a033122bced0464908ed0e6d28565689b2b6a30fa53461972a26b5ff46024f2,
        0x29b13c0792af982c8ff3463a3a77c789c4a66587bfbda4d40ac8126c85a29ae1,
        0x0ab989ca09abe5838849dc206d322fd044fbbe9402e726b58b525a468609a7a7,
        0x197fc744092b5e46b0bbea57ec342e871c9b35920e846792c671d50b98a75508,
        0x2481d242e3a39c7dc839666f35595e82693fe1eba9f4f9dc62dfea42ae6d5edf,
        0x17bf661575c0af25d0da1d782e69c4fe26768f18bd43f099e1a0e0e7cb62c242,
        0x276fc35afe69a36c30ef6a49f3554f2452992ae0c4ad0ca325d16cf9280e7e75,
        0x0ee7db2eecb0eaca0302bfdb497c4921564d332b55775adcd2aa82b8d358dd36,
        0x020a340ca4419b3cbc5637679299497765c6454e7d9be42dd0204534c3ee9e8d,
        0x06ba09751fb654f7593fe72f38d0c0b2ad6f3238b21ad1e5382a84b0a194a2db,
        0x2523c2dc87b0ad275b15471fb55cb7dbd1fbc151ecb5a9a1a45173d899291161,
        0x060d8fabc3158969d132f0bfedcfa39a789428b9b7cddf4d6db22cb288de313c,
        0x00ff47c0f3ad1f40ce7cf45911142f72b193a771546517674f1d91e6e762895c,
        0x08869a0b55cf06d1d0babcd06078cc338fd9003a4fa832b3c120a79296dabec5,
        0x0ddc122d99c9e7410bc1f834eb522f0f11ade5d864e9fd7c375f683e4fdfac8b,
        0x1104d75d88d2229e89a1fcece114aea2b27857e60a9b87b3589870b6a98d11cc,
        0x090f7116a6a6bdeb5b918856cd14a41a419539399f342b3ba0a0c93702d3be82,
        0x11c4487be60bdadb77dbdbb90097a49b52476fea5ea0df86efeeeea2d963debe,
        0x06ea7add48d9bd61c385200bb35edae9b5e796a85a49d34ff71ce1b8fb6e7cee,
        0x1da9d7e408a943d9ff87601dea81df67fff3609e21c91e8bbf218293b01fa187,
        0x25c7d70476fd91bb1f72b06eed2f63bc455e24608ba1e8e09ea86621d33396ea,
        0x1a0ada56d28b9e730eb27e19f5f10a0306ef8a1b2f88060ac9ee829ba0359fda,
        0x126b459623ffab27b9068f24b598ca5eb76c519cddfdeb83806672a5ba13848c,
        0x252d593146ad911e6ef9af64bd80c31909bcfca654589cd22fd5d355e5a309fd,
        0x25ca24ca7aae97ac6aba108e99188da5411046a48491058e8a6a0ac5deb97734,
        0x0538975e6367b39f3d3200d88d0b4e1e256ce5e9dea780459849e2ae7fb2c2a7,
        0x0ffc26a7e0c55072fa30b05a199a2ba27bac806b6453bf5f00253790428a7956,
        0x2706841422df0a020c67326107fbaeaeec9ce3137e7fe1412b702432158b4c75,
        0x1ff30e494eaf288129b2a3ddf6c8af7d572d4dd3128540eae494b497cedc862c,
        0x0ea152778d9645e23aec29c2ae8ab1a0798412b774bcc9318caeafb85cc6e00e,
        0x2eea3b6e7d16fdd46a27a72dc717516284c7d4569c1129701b621a3b990314d8,
        0x2cc5d1c0fc8c6b6f37229708d6aa73ddbe2eff91a79e1bf94f7e9e080345743f,
        0x044eb883f772ab28d41058e4b818b24e43ee3eb4b88ef0e527f773b85cd874ed,
        0x232053c7a4178f088bddac78ad99fec4a65ae6e8382e9e7d91e2a4a529721529,
        0x12f303e98e5f3839ed1d158c4efb477cbc8ad10bd9423e73034bf1af835e4c9e,
        0x1bd3e7b0f62b0460540ee36e6a572b9197c5d3a7b803cb8e4dd5b6fe9e7b54c5,
        0x0b5403a423d7dd802d167e8130021bb8cba0facbd72d0077a9d984c362da2e32,
        0x2f3b031ca7e8af93d3fb9df7801a592a0da27c5f7bab7c9a79ac2765cf7c275b,
        0x2b697e5aaad3614541bdddf1f9ff099eb0c4285575af030617ad16b9bb848676,
        0x050d3496a0c05b27fc281d4aeb2129bd54c3b9c2ef7c8a63406d73afa3373af7,
        0x037d3c50fa200b42c7905db6c20ec682796d9017f379305a11702ec6e54767b5,
        0x2b4acb3c9143d503f15354950964bc7051e93ce0ffed0e41b146fe494748e26c,
        0x17b8f71d200812874eb927688811be357a23b6ca5eb3fc596354d3878d90a6e1,
        0x2a68cc2ce38f8d364292125185a331ceb63cdaab5f3c7b70524d693b0bc45429,
        0x102f919292719bee42e8a51f2248e03c28a12ce3726e2299f9d7bd31b9256c14,
        0x14dcfa622fd5c4b6ece0ff711746278d0b1eda51271ba9c8f7c7721a6c94c973,
        0x2c789e6e71d25fe1bf6f6fbfc7d74eea4e0db9d237287e0111986e1edea3e951,
        0x067d2ce378256905ec078d68dc1fa1eede6235d2479496179cf736c7d4388f33,
        0x2d1bf8c7ae201b3121b9661ac6c2773ece888dfc2c0bb167777943c0c1bc42c1,
        0x258ce58defa852c1e80ea06f7ce7376b8af22391df333033b5ae3fd265341e19,
        0x2573933771f6f384c444ab91effecb9bf02f7585f15ee187540fff91121b3193,
        0x1670445b226abc20163f4ac7d5cff9b713009dd698f477ee784b2cfb12b3b2e4,
        0x15201542f8f9772e6690140c17672d1fb5459540efead31a458affa5209515fd,
        0x0945455e35234051bf74dc4635e56d917dd809d04283d6f6c177c02518d6d5ab,
        0x0e2a822824033325895980ecad43da320c12b88bdae24d98b55b94cb7c4a8907,
        0x2c3ef4d6fdb4db244c06a195557fa8dccb47e43d946b33a0307a067b38f4d0c3,
        0x025bc633a4f33575dbb9a8c598223899456382338e9dd4a52adbd9b779cf8c8d,
        0x278db1c1b68c094ac8edffb1ab2d13da78b5316f14faa7a375d4e2112cf56abf,
        0x120cd16c04070c8729d940feef1ed8a7e38efd6911eeebcdad7c2a7259f6e3a0,
        0x06cc3e3acb0d36b88d962faa4632ec3c345f87a2e81f659af105c29ec12623a4,
        0x08a3acbe72fe4113f8e24069acde1e98433de864542ecbfac0a71c73d5327b00,
        0x284b7c6a05c1d10f0833fbb81fe10b702d909edf7b05295892c27029d1413d24,
        0x0a26530f69db33d8eec5b3cc4b15f5eebbf3fb1ae09a5bb5c9b8ed90266243f0,
        0x298e52b87df7c8d9b786375e1adbd48e59c848945709f815bf1db160ab333dd5,
        0x12f32063fb6ad00b7f0d0dca1debb10e3c6b2460cf2de9e610985cd9f66af585,
        0x2d267655be98bf0435e2d843d4875c3410d4f745b000f88b738337d52e45044d,
        0x238343eaec970af6a901fd4a395fed50911f1cd30626cde1c965a888202469d6,
        0x1559ee7e6ad71b2e51183ecbd549b4f844fa217330b0d4d743116acf853ef948,
        0x20ad47a2344e4128d752bbc6d23260855e37771a20bfa549c538957e7e7711db,
        0x08258bcb391f1019aa2c6b6fd71744ce7c4d9a69a1eaaaa86a26c6a36614d354,
        0x2bfd6348ef6d63e0348586ff579eff53052153446e9090ddae6365754474ed4c,
        0x0c8e0314481c4b13dfa413258718d15cfb71b7ba6ec358a4e898304f32a9d305,
        0x11f029f2752c58a2a8f6f2918b17e91dae8b02c2335f1e1a6b51d5ed4244c0fc,
        0x058a47bcf347d45d77cbebf9e261f1f4e57810c09c5f552427b6daf9f2af2175,
        0x0e10d5d72fa3f6116e2ae6a1add5e5ae9e60cd20d102e7749b6e25a2aa826eb3,
        0x0049b054352fcc5acbaa748deae5e9d9f7d1d86c2ea5b93843d8a32c73d9075b,
        0x22505539b553e8fa90d7f0d3bdde5668878e24f4d52a59ee239190738238bcfa,
        0x0435b9134ba56d2f5a9f3526f07f172ea75032ba73f6ca644eee22e10345e59a,
        0x17cd6b04e366f904b6f9c4423b144c0c37ab8e3790b29aa5338639f54cb130da,
        0x0bdfab75982b48b2e27a88156b0309494a7ff638288ca6ef9b9d7e56e2492877,
        0x1dabece9bf4572c906c1697424f6225d656c11cf61a6e4c558e0174761316ccd,
        0x0cedd3bff56db431a4ea2810fdb67ff1f36f8064f5d665b3d45517c0fa98c5ed,
        0x0865b5dac8334dc2cd345d6cc677c257982c837c2197b8fa488d7d5a7c79f5e4,
        0x28d67f9613256869a1172c839bfdd63e85a36ed35b1352412953ab53429d958b,
        0x0b6176d0867432589b5339ea19f583952efab3cb15bcb6c0cd6d88859a3dd34f,
        0x23850c0ed09c94226b601c57b5b0fb41e5fd6c948906b4cf192c5756fc284373,
        0x0252f9352c413a425e6ed7dc1f2f8fe5d2515e344d61251c56c7d0bd3fee6556,
        0x148561f88b0232f760ad63b212ec755946baa467ba65278b747b86a8aa07a5b3,
        0x21e3f46a5708aa4d05883ca0f3c3e73a98952e281232a8f0f0c5352000f85b8c,
        0x1e434c2e5b26f2d89f02566f61bc19af1d211c2b1ed0cbcc58a7c342d0216a9a,
        0x22563ba20ff7d66c71c0e5813e779fe6c675c3cf19dabd3e3952cc00f4143101,
        0x1df83b586996a1cc23cca932f9322ad9a6909d405d0576e24aee6d19b2a54f73,
        0x28382ccf7a8656d242ba83a3157858df570d4f2fd74e45fc14154809a7d0e8a7,
        0x0b8d9549549b2982de5e52f060a9884f63939378d843e7242ad9e2d8395ac25e,
        0x29587dae39b268b017bc806bea60ed89b7a2fab8957fa314ee567f7694f93d77,
        0x162a3a3347ae57173b23e69eed4feac090deaecce4fc7860025df73a56090293,
        0x0a0846c62ddfe3f64e5bd7a39fe838fe437dd899bddf950adce1ea8e4cb301f1,
        0x0054d69335d09f36d02b660439f3e12360f8030e2034ae7335341a4891f400b2,
        0x135788793df981e718b65b5a06501a6d9e27e94f80bef9a233c10e2988089c34,
        0x0abf8d2d8b4e89c3dca90a2df44abf686e610e1a8dcb4f23c5b7ac4dc0e9780c,
        0x0ed6286ee37ce212ab27431033b18e0d74fd196902bfc70725550350c6a90468,
        0x150b5c19013a0d3253079b93f7d70e0b47d086104ccbc36190c01777849bacc0,
        0x0ee51859e23a841aea64543318c970088a72744a69fb9dea0fdcfcf951d645d7,
        0x0f86cee78ae20d4cf5f362577e4830e72dea2b368dc81e03907a312c82aec33c,
        0x25b5a95def96406c6b9bce923883f5bebac9a03eae2cd33b063915a9f94ea306,
        0x0f09ff1a60dd952a1bce74cc80a414f9fa8c6e422739e002af84c87b65f237cf,
        0x07ede0fbc267b87135707c54a8cffed53d28b45eac53674b495f71099ec76eef,
        0x10eddb8fb0f8ffc304ce336bc4f572c8caed52dafeedafb49b51dd835c6e96e6,
        0x11bdcdcae9c1d0cf0238864dba912f1283b4354d873f5ef22d819a6fdeac54dc,
        0x07e646a5ccb40703b896627a67a250b14c5236db848663ebf615c2591e170c72,
        0x18623428dbbd69130d316483b08fd1e0a91a9d36f037f96620d8d9083579dba4,
        0x1f84656378c69a6d0dbb94f67cd22a8ff5bed6ccffbc1238ebe8bd9cf22d0eb1,
        0x0a74a929687b93cda19504c44f6cdd947744d08e66c45b3e6f479ea18f21674b,
        0x225b4bcb9638686a42e82138d0666d3b019a8846f05cebf4739ebadb56db717a,
        0x1693b4de1096620afc876af185fda33a69261992cc481e8dbdf767ea9e4e191f,
        0x25c22cf444be68387e41660b08994e26e281f9780e0cf4ffac86f9f745198650,
        0x21f47db95884625c87b2a032fe6b3c79506bf808d81d0f856348d14c7a6b6c38,
        0x2c6e4151190280bce4c50cf2d450935c9201b68ae4e94bbc4c1c8fb3b6aacdc5,
        0x046b60ffc82e0d0026987018b3feb4b1f4871d0de6282c70341a64aab0997422,
        0x05ab33dda20d7f58b8464e4a839f940760754addeea91f14cb57612144f1f14d,
        0x0beb305b4d3929518c2f42fb08c1730c59b93d9e30b7aeefbe53c473640821e9,
        0x037ef370d2a1bbd37f00e5c481acd7c3522fcd99ed730ca9131c80ab69ca4c32,
        0x2a0683594b2b24acab440c1471a453a07c88afba19ce27e09335db9d76155c3e,
        0x2e437dc5cb69134def607c4b1868859af79929921dd3c95ee49631ef92d651e0,
        0x0a9440008322d116c16dc562c36137889882a49984076292154d599cb883ea2c,
        0x04a10c2401a42d12cd73907d74bc9e84d0f1d43fe4d9f8e9b906e60f4871a7c3,
        0x05c2a6a81ed4724bde4d5778e86b267c9149adc1c83cc77b5dd4774bebcff233,
        0x00604e15f8699f37fc34ee527c25277b1a7b819b4391f4eb97ae1c7795a722dc,
        0x1fe306488f3485b485ec95914aa14eeec7fc1d8b6e1dc1b5a2edd45173c4b6ac,
        0x2fd92b003fff24be07e4cbe499c4babd15a10dfc116015e15d57aad19fc0eedc,
        0x26c8c111c1797c190126bf33acbf4a9eaf80e52db0745926adf4a9de61470d87,
        0x19b717c7af2958be91a595ad756e45791b4da66da72367c53d906d6bc5e2b15a,
        0x2a9f5815c788adb5e34670b549d7516a633ea53516f1b65374351af299a65bd0,
        0x2e999491f98dd3f807fe2dfa0d1367fdf0f57b24fc4e8ae63fe73c3f2ca00b4c,
        0x2cc5ae7e03a10afbf19d89388b822d56b57e8eb3e68c7414683f27d896a07c5a,
        0x10ff257333f10cedc7857f44030b245bccde4a898263df5358d5ac650fce9ef1,
        0x2b6e6d7ba8d2c1f83dc8cd979c04f38f79c06e4f324b87592557facdd954f8e5,
        0x25f472ac5bfc784af9dfa96bcaab41cbcb5d7271615165363cdc1bd1307c2425,
        0x2cc4604b50928416d6d754d02200bbb926aecfb45865b9e2dd6dacb8bde2626c,
        0x06d9925be2346e3cd6df68f352ba54b0c055d5096be1671e6a4d36dfbd096c6a,
        0x1453cdf0e5671662d851c09b5ec053687dfa9ee5862d7435d547c6dd6e76be80,
        0x1dc5ac7dcbaaa11c4286514e13edcc6b91261ea12943be307be24691bd017ed2,
        0x07a8fa5301fbaf95ced84517f99af5056110294889f803333330cd3923cb32ad,
        0x2a8253df4101527de721c8d9a396d23e0f99abc8d2f411bc7e8e9ec8146c823f,
        0x119b0cfb576c0157702aacbf13e96df863b85a05020a39efe054494b68cfd1a3,
        0x182c5bc30e9f3300fc07dbccbdc50fbc012fc26e4d8b7afc8918350f80b50e22,
        0x259df3129f7139b8eedd6155cfe12635d1b7d3e3f5dd4c47b0b2e76da961f43d,
        0x0f7b3bdd12c0087702d0ad40ac23439660cda1c39bcc9d35e2095b8f339642f6,
        0x064130166808fe7dca567708f7cfef4f05f728142dea45cadfe4eb45c331e0bd,
        0x190996c7990b08af6e51ab50c419b791ba52f4b2854a49b67d034105c265110d,
        0x1b704bec77ae1907f2076ca2f4051d47c32831045805f82730113a8151c6f353,
        0x280c8331f3ad7f3a1cbddb59d9e80e119c0aa7755d1e64b1c506e62f05f74f75,
        0x0221185e67c1aa9f740453f1dd54da3e51d9426c8f35ae3a7ab414f3565f0405,
        0x2b7b9a982dc45453781ae5c2c65980492b42e5455e1cb563c873e0a2f351305a,
        0x2217d8bf8dbdbd97589da802081c9a6f8a00ff315fa0b8aefe162602e7e8143a,
        0x1597da1c12c6fb440c2c0621f8980a36330657434ef647e50ae3b4c60fb910b9,
        0x1bf8de73601c2bfa0b410595aabf2b7a89593075545a6640165faa6a47ccf7b2,
        0x29bba93f55cd8537e1e3fe8d8f84142ec6aa94f1ce6aaf227e73ff30ff5937d0,
        0x029a65191c680574c13db8f0c56283e0b7a50075904b8defd76b0238462c2313,
        0x02863fce7b6f7ed6d852aec2e646ca3bb0b0f7d29e2234bbb5e5c17619b41003,
        0x18149a8c5a759550b017f743001f7a5218dae3f47345f9d48948dfdc0240a341,
        0x091cf42928f0753dd88c8ce7b2f7494d98fc53290746f1c9e5835350b3e44c0e,
        0x27588abe46f62632ea96659a8414031d5c0b89db4f92465caf2645f153040db6,
        0x2a8491794820bdc9e37b13d3aa2b5835eb8ce36a756c31e800c6c797bc4eb53a,
        0x05975ad8511f6b2ab017fe37adcb2dfa41e82e11020dacb53a7d125f75974999,
        0x11999d491e307438574907bac3b0701c1cdf817963d9fd6563d8a3568859634d,
        0x1ef6edd6b0528d9f219ed18ac7fbed5a2d833911ce2fd7151c9e6175faaa375e,
        0x10329642e9a1b4947fbd7a3cc079b67d121fc7efa0520a0f9e34d8d53b0fe0c4,
        0x2908c1d55f9ee0d8cd2bbed20c36193498f2fa5c189c67e53678245b7e4d0fde,
        0x009c7cf3957dca0400195048a4bb53759d6f5543092608bf311a558771fbeb62,
        0x06bbee41b178b54260fcf86073ef91db8a9929d532f8ad3f333c765cec0e0f08,
        0x11ed2dc80f11b109c5592086e29373d39c267beedc19a6c51cdeb30880e31b0a,
        0x24ddc094d7e4ef98614703072e569c99029ea2e52592d0872aa1ee948c5417f9,
        0x24d8e96acebf1b69062a6c1a092b9e2e8143ec24b90099e2bbc584977f2291da,
        0x23db5c7f0b4713b40a6c8276c656577a6ba8a59b5254dd1e2dd9c43169b929b2,
        0x2abcdd06322656098082287e6d6917e1201650e11666eb96899824df8050dc54,
        0x2aacc44089109ad6976224d531789b97fc06bdff8eccdd324be01ccbc6c0ea91,
        0x276b874aa652cab6f36007c2600476c8c71290d45a402cbada53dbcd194f66c5,
        0x15682e53f8933b80e0cd1adf54b338eaebcb78dbe700f86cdbe770ce7b0b5028,
        0x1fdc786e14f7fd42ce591e056833cb51e5707d789b7adf7abf85ed12ad648366,
        0x2c1329c3ae627f2833ad8ae6fd77ef4fad622d375d5bcd6b5c6f4daf4d2960e9,
        0x261f2cb4d89ecc9d4a4729741d5d84a5d5343d21165f3282486323420fefe8cc,
        0x043aac97ff0ce16e4cc14e9aa8c18b66d20e8a1bface9b49e4d9f0f10b0dc0f8,
        0x1fa692dc3e9f09a39ac0c24cffe9ebb17aa9cd190ca59c4813438445577f0f7d,
        0x0dd01b1b9e65dad12eca2ebc0c76432efa8083b897dde0e984d2db68eeca0afc,
        0x039baf53f3221efc825379714c79958f8c0e00ef751f60b9e31043777699bb05,
        0x2911e51d52c3d00babd351a51b6205283f4f2a0d2c8143a4579683c15ad0b2f9,
        0x12b465d84ba849a5c1129cbb207545eecd7f457cfdb096e722b9519802614c31,
        0x1b6103e09bb91151eb825e54010d0a90b2f871f3b80fd411f43984a7e88d143e,
        0x1669b8f39df093d2bf16486a315f33cc56af00dcf5476e5b980ce2ad97bf6e8c,
        0x0b4b9cf7b3e30b0541ef5b22bc83be1aae20736b2ad8b4f42e2f24e65250b1b8,
        0x1c3169c55427ad80216660f252732566f7138e8e9d72553697240af77ba3c37a,
        0x2f03001944e0ab0b6291e4acfbda0a76603e5a3d66c41a0130f22b356acd2ce1,
        0x16e70d097c6a7be6bf358ad9d946330e8e9bbba8fb6a6ed690ffe8223d006ca6,
        0x1c8d6ca753796ae170686255f212a0ec60df97bb94ef9e6c8096f8dd4f8330fc,
        0x066f76006b85155ab6e194ab68e0011b2ecfb1ff57d69d44af59b09b79b29926,
        0x2124781160b9f9efbf04372db7bee74a26bbff8dffd6a60b3b3ac1c4cc0a11d3,
        0x02d5c7e3180a694d4f309a5f968f301fa837cf9e0f2a1615a8268b25fdfe1134,
        0x164ab079ec76497e5b703fe787cd960ac73d31cdb00ac31c0f4d1586c669d4fb,
        0x1e2ae3a3bc434820a6d26d88fc20c76b4888343f68f824177dbecfb0f877a5dd,
        0x0aaf24f62da2b73ac4e9eb2af1fec4b1e4375da0975cfabd95d168bc79d0657c,
        0x2cb025f6132a889341c0ec078b8fae21b34b6c8d235eff542044786f266a82ae,
        0x2746f704b9f38ad37823cc32c6b6daee8cb4e23dbe5f7508edac571a46712fe6,
        0x0e94364d9f324e6e9e47f1846ea8b23f2e37e8c22643c6e64463c555a1385c21,
        0x0a686d66e63d381102192c370514c92e73ee0af6bc724e498cbbc7687966d51b,
        0x2508f9c3bb5c13e26d0dded01a68b6dc747200319c869352cc2e4d1444cbf726,
        0x020d9d9337cb2eb48daba66f17a8865845aace249c22fd8ff5b8c35a13c1ddd9,
        0x0f3d704283962b7e830853c5dff19b1fbfd5248b6c4c07cf3f4b399076b30642,
        0x1a352075031d9c71484c9625ff74668c06e30628b204aff96c48309ed3ea5d84,
        0x2b655c81bb4b9efdb5e522fdb65829a60cfe66a5fb862f29483fbd89d948e6db,
        0x0677f0836859e090541338307d923b3aac98dd73ce251c7a473bd273e019da17,
        0x2de07656a1019b8692cc7c34e5e3b5d9f985fd2c36ec8897bdda249173c7da10,
        0x26f553c5529448a1cf5da3f2495278c3baa28ff6673934390892f353479e7afa,
        0x2221081df73abca4608577a4f91e759c5454a993aa205a60cd06235ba95366c3,
        0x2b9968a8a5679c8767d50f5dfbdd6bdbf700458de165a2e4ee9f39dceabc5381,
        0x2058d6c705ca910c4c89c3f20516a831ba672e7a3f428af1f21b7bdd4fcd8186,
        0x16fa3b29cd592d5bfb42f9163f67135f2b238650c30d3b3def231aaa0e2f5ab0,
        0x255064daf7387500907820e804fa168337e76016234d57bccc653606cc7054ba,
        0x12b145f88710a53a3b3ab61a4e8776e4e877a5f235560b53f0b9526e50fc3b38,
        0x2a2627b8b5d8aea9ec4cedad4ca8393f7d9a1a2162af167ca17145ca9d034577,
        0x0fb70eb291e12677be8186c06da2d037216090170aff6d0b1ac041aed2d90fc8,
        0x205cd181129cc42d9542360117459621c1ddd66409c4c3f1ef3bb0cd9527d7a1,
        0x038b737fe726f168c1620c7d6f498d25c516108638d48ad49cb1630e2d9677f4,
        0x2ad3733f5fb5a071254c3e297a330562f54cb332b4ecf093e72d1469b71a8dc8,
        0x02b789e19c4d446315a8c3a068971bec647a8571dc66b96451c64147a4a3a82b,
        0x29a33bc1c28ee959d614466af0c0c5ea7ec68d9314c8c7c54f0a30b2e2bf88a6,
        0x02a2b7d8e34b1cc803675fa5e52b13face5a69cab01fd389742a6da93196368a,
        0x1e4e5e609630c259c7982b70e3fb2692c10f25259c383ea64717f9f9cd78e236,
        0x15933d4f34718cfe5f60207b9cf35946e764d1013e34a9ad6faf4c0aab1294bc,
        0x29d0a6569aeb62543fe8b4c406dde6b568b0fa7452f42f9cf03244e9538114d3,
        0x17e9f89117b8cf81e2e5cf757b9176ed9a0282bfd8a104621e571718c5684214,
        0x17a6a25abab58e47f91586b80e6804232d7ec6d9fde548f2e56d001072225212,
        0x084ea708bf682158e14f380eb301ebf3a62cac262cd7caab43ef0e7468082317,
        0x0e55eef14308f971956e772e49cfd1f25ebc4127623860ac8707709b0417884b,
        0x1104b331b2d1736d5113cf0b88854faa635ce6c57a9e35dbd4dd95074c427046,
        0x26b3827a100e4db2b6cb4b65aff54e129c809ac2b2b9f2912fa3f77598dbb2a5,
        0x3050f71a4432c87820379054d9df9d3d697cf98d3b8a123ab976e27e4ccd56a8,
        0x24cee563097166f838fed9b079dedf9ec489256988767406617d5d5515445f09,
        0x121481f71ffe3df6c446eb0160c500c7eae33d31e027247f6b73b2834980ac9f,
        0x2a3f2ebfff57c0791bcfb394a7026cfaa75cdcd17812a1231d30b915d3f8c9bc,
        0x26ff86e3f5111313de01a8ab7ed5557606931cb912c561c7a1d8afd72e6e6077,
        0x20c942f6fd9e5a41aa62df6cd8a88dcefbc513cdfbace7d4c0acc538c816dae6,
        0x0ea305909a716f70e28a2f4856beb557ee1e6dfe25d45654c74cbaff8c1ffe75,
        0x2848b5145382ae6028b6efc6957abe4c7ec6470cbf8650a8d1f04d1fdd888b5d,
        0x01527069b94be0ea68e10bbfce949971301286e7f746560e1c7c15124214275c,
        0x0da2995704df9c41fcfedc39cee6590879c57f7005c6d9501a5cd1549b773974,
        0x11f30187fd52ef26030693f78c0becb2aca53779778846834e2236620af11ebe,
        0x28c3898f7db1e927ae71f2e8f16234f7afa997bd67db2d03480d52ec43ecd9db,
        0x1917d205b6d1985f71ff937ba4c8360b5e16db019fea26a0c2715ba0b7060782,
        0x0c4d2207872ddfdbafb1de166fd3053d834e5e8538039d362a5c6a41be93b77a,
        0x00c0ff82736b149a4b1697c9b65ae6d42c87cbab79519a1c157e6296f0908a04,
        0x20b8d4e4a620a8a90a27dea53dde4ed5d5bd138386168abc3fa52d2596a17efc,
        0x0212fe4ee38a6dd20c1bf74617211b8d723df640233014bebe9f03e1b8420a5b,
        0x14c6061894fd366f12c8c1ab0a4df285d82075c2a8bcb094176c41636c6e76ba,
        0x2b0e5bf67a965b2077ae5eca21a42399c966ae411574b352afd82c014052cc71,
        0x0dec936f4f71ce340ac1fd7f357f32310e150946451d923cd3ff82dbfdf85f86,
        0x0833661337c4bd28e8615ebe899bf52948b1828a00544b69c1c9bf1b88eb1904,
        0x0f7801ed6d61a83c01b088324368a39e302aea1f703a9d0e0227489873500a0a,
        0x195948878156461ca5e2f6e84163c40523e11f9c48370d8bc6f637c77bf54db6,
        0x1845bf9a0403d6b8dfbfc735255652e136821ff021f0edc1a0e350abf5750d7a,
        0x14f3bc8a23baf8e015a4c2b1c63f26ef1cd3c8280909326945c5acae09e48f15,
        0x25b2df5cdcb012356c3716c57bf44fba7f5433fe0ab6a23cf7b92c164d1ec844,
        0x1b65466d5c3824660e5d95a292ba846e8916a37dc582455c5db39658c2b641a8,
        0x107d686f133f97486df323e5a071023b9a06d4f831c641d78e6812dbe0165094,
        0x15f2577c4c9b9da865069bfcdfc70c9bc512cb38c114349be6800672e9929c39,
        0x23673a465b71e3ef9b29712c472c552556731b5453e8ac7d05cf81c03b0b02b3,
        0x09f80691c639f99f639212f9a073806cb958ba6c9de7e21b05ddca60a8a1946f,
        0x1a701b623e400f5daa92e309c195e667f21ea190fd14617efcbebbb5932f7b45,
        0x0a316396f127dc5119f06c95ea2f83973e77e4ac308243613eb4046990ffff4f,
        0x116c6195e12ac97eab1947900f1c7854db4349ec9b45c34fb8acdd43beede355,
        0x1877e8af70dfdc693356762ebcf0cae23c5ccd5fbad39f23e00e1d5b1fa7195c,
        0x22755aabf9a032853b0f49fb4d382661de9e6acd1009675789ddcacfd7ecdc4b,
        0x2ee0834177fb40e40e7844326b9812be36808010d4a564080e1707372465ee4a,
        0x2b4c25633203d27626881e894b5db083d0e70b4ec757b476b0e459057c34b1fe,
        0x033e057b3a88c1b2856f7ce7931399d212305efeb0a5afff7ee90a77f03a5be1,
        0x232b1cde31453151b6ffb5129c81ab8195e894b933d46e8969383b664e3b6083,
        0x1f03ed585179c1ef833c0452aacf5c37e5af916e1a54ff256c5fac7f4cf2c559,
        0x2687a62e4ea3df289b3701bd9f09a319d8619110fbd759516b38f23f26b4249c,
        0x034c014f502293d79ff2be303ca8e27482faec650fe728dbfbb33b77987ece4c,
        0x236cd0a1d3c08b6cee682e2929318289f71f23e0c9255a8bf710a55b3bb5cab1,
        0x0648ee7a1c1e6d44e86fd675a0e2cc7ad573e7c25a1f43b7dc916a39ca39d27c,
        0x2bee3f0cfcd5a7783cc72410b25f72199c98bb9735ac81b770a1583ec5ade6eb,
        0x1c4e9f70e8f9606b2376efdc5401d0a8e7437c1ad3a0b6dd9b684ac4b345a9db,
        0x158e2fbf8d9bed68d6b33c224d0120db7951c05e07710d0d9cef0a5ba3d350f0,
        0x22864d60c1635a4e8ba4cbc9b5064c8043c730730db8ef248bb3139377a347ce,
        0x29d1d4d22912c68184bd6f448d9f1dde01b791284b0bc2c31ad5171335f8b3fe,
        0x2cfa5037dc15aa34d77cfb07af0f707f79b1170a6ddc96bd4bc067ecd5556953,
        0x19b35e49023f42a4a31b7e32e442bb9b987a9befa3d7c49a2b6afc34fda2602e,
        0x0f0c286286df6c840081ce60a510f5435cfecfcc8371c65021c3482adae55a67,
        0x2b6dee4b250dd4862ef9210e336445e629b32871615b5aa9aa933a180ccd45f8,
        0x06d730f3755d577515e3fc0ba6930efbd6681e3b2f835f09d2008030b7337e68,
        0x0f9edd7b8db7bd85d3d7d04e6f570947e56c6d9d468fb6e21bf2cb58fefe6267,
        0x24957bc8cc4168f6b41693915d82b435dca765a6ce98c85d823499b8d9320d8b,
        0x2a20671033d18afb1445e1bf5399a5513f3bfd9305a082e7a541bb104ce08e9a,
        0x19684734f018504d5880433c036501430403a1b488763cce723ae9a20c6004a0,
        0x1dd8a1c8315c44c98b65c31cf62ec1cc6d3461ad3961d057e77faf8fbfb34a6c,
        0x0921d1eaa625fa5d3879315add5c82a3b1fce31848bea55ff3fdcf32551e5007,
        0x1ec5196a337b46d44741944f25127ab866ca2043287e2d7c54223a2949e9c36b,
        0x29d77923cd40a984ea49957149f724ef59dbf1ca3576987e5e27251592663d34,
        0x1e222be65e7f3b32b1d5e34b5e6ab9bae777ce7ba61fce7e64cb6cee68b458a3,
        0x0a012e2930d1069cf1e223fa242abf8cb8baaa704918c263b9bf11369bc5eb24,
        0x2430e34ae08b420472300ed22f6a191aa138a92c5f2fd13fb989deb5569fff32,
        0x1461aeec3702e1cb7f79b02e16ec2ad3311f1d7e63848c7d2e1f724166e36829,
        0x01da0cc98c85e9a522dbe4379a6f4964356803bc136c056a93db98f58681bc10,
        0x22be5f0c8c6c73078d268c5753d46571813f4a0ce99bcf5714125cb244b610dc,
        0x0ce8ead0dad826910bec9373dfe829bb09000c1700690996c4f7f70b5898b951,
        0x17992835674848ed69ce6b6129bec2210366477ba9836127f810e869d6688060,
        0x28a52563b87cb481fc254508d6f73af6291bb3e55feec2157bf3b07ed03105a7,
        0x1fd60a1e29b71aca0461ceaf50871eedb6edfc047ae629456911638e8690d51d,
        0x10edf74ee1010d165d0a545f3edda080f69e2122f5887a43f5d531ecdc02bbbc,
        0x1642ff3f352e4a0bdd154937e389a48234a320ddc0dfb6e9686984266b04e0f3,
        0x1c0fe501f5bf26c7207c61f1aab2d250cda6bd05e90984351d37140cd6d92f51,
        0x18ed3d5fa255311c0a78d4c365a9f2dc95b4be94f7fd899566b74d4a9f6b7a26,
        0x199b50d23e8f11124ed30c5ee1a6dbd4f30278ca0dd514debd50ab1653b09a1a,
        0x13f2e8db4910159d2f1eeaf4719a7d626fae859f1d1f1c22c65ea37337f95041,
        0x232e9164fbca661d1e9e6460bc6ea802e8e271cc74d1961df48c612fec158bed,
        0x1a1a04c22533388652c6dd73455b170c03a055d5cf6144af1968a4f3839127c2,
        0x2dc771310783451f8ef3a0f6e437211d8dabfd860fffa6f900bd45a4d98b1537,
        0x25d2541b550aa37fb081117731c60f74e6efb546b78fb8eb7ab0e18f3ae0187d,
        0x15ee6e7706aa4dabe34a4b7f3a01f01f266e716235d00d01343a93a75aeff189,
        0x2b86c9de07f7526fc6b53efc6ab4073f96abf71777fc1e3ec35a3a57b16bbdba,
        0x0fe44940d8609ba0734c5b5278f733081a8b7d34aedcfa2e0629e7a1cf27fb75,
        0x1ae5d493778303e2911ce7279de3c113f35c03b4e62fe45683e1d256332e7a39,
        0x2076de9f66b1f539ce0fccf52eb5be7a84842cc9cffd856e0ced8d92dd57710d,
        0x111f3300c4213d93c1b967a6720eec2a762cf2e544be25d9b4a52ca0e75bb238,
        0x1a19a3582bbf40306dccbe41c0134ed50b48fe5aca961fa2441f9febecd55bbb,
        0x29d0baddec05e836192f0c360bac00770d2e5be997bf66fbad7aedd6e9659a51,
        0x1c094a1183892961984cd8f3ba683c9b390640922579b627a8f81785f61f8de2,
        0x1fbecd025b5c9b0174984c0429c4592d05e15d2b17369de4326ea2c64fae0ec6,
        0x0ec21aaec8046c3aec3bec0aa7e65fb3de06f52f5877ab2659462972c07ca377,
        0x05751ddbe67d3a2820780f56ca2eb859403c80312b29c2e205ac5ed7a1c2ab92,
        0x0b12b40f3f53a5cf49148b9c893e56e124590e25ae27e6adba86ec65733c6c4c,
        0x1720877ed0f4faae162a9c7bb222ee7439ab32a961c41c8539b288ddc2e43110,
        0x2d985a402cab1022f65fd08fc5a801c43ab94f4fe1fcdbac39fa0e6b7a2974a4,
        0x16c5673fd7e988f2d679d3e5d7ea84b7e3ab68c028b68f237ad658190808fee3,
        0x2cb759866141c8008f5d8eb94ffc1d73c8c966767cf1430b64d871994209b06b,
        0x149a0452616b277d8a8b81dfeb7fc937599afedd1fd81a81c7f2965437e99dc3,
        0x27959c6d2c17ad452084340178976a6fd1ba34513136f7e6de2050a58e9c65d0,
        0x2152030c7928e8f77c1176ac85561c4bf27ff179d86e05925c977dfde744d3d8,
        0x06a484c6cdd70b80963a22597aee524779892b6595014061a62ad6527b7ea0ac,
        0x07e651df50d21a07f4d3ae0e1058ec584f1e25e258d6b128739070a81a317023,
        0x099b86f8a9c8738225fb2b8a1f2f5efa431c2c29bbc1a70802968b6a67603de4
    ];

    function get_lagrange_base(uint256 i) internal view returns (BN254.G1Point memory) {
        return BN254.G1Point(lagrange_bases[2 * i], lagrange_bases[2 * i + 1]);
    }
}
