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
import "../lib/expr/Expr.sol";
import "../lib/expr/PolishToken.sol";
import "../lib/expr/ExprConstants.sol";

using {BN254.add, BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {get_alphas} for Alphas;
using {it_next} for AlphasIterator;
using {Proof.get_column_eval} for Proof.ProofEvaluations;

library KimchiPartialVerifier {
    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);

    // This takes Kimchi's `to_batch()` as reference.
    function partial_verify(
        Proof.ProverProof storage proof,
        VerifierIndexLib.VerifierIndex storage verifier_index,
        Commitment.URS storage urs,
        Scalar.FE public_input,
        KeccakSponge.Sponge storage base_sponge,
        KeccakSponge.Sponge storage scalar_sponge
    ) external returns (Proof.AggregatedEvaluationProof memory) {
        // TODO: 1. Check the length of evaluations insde the proof

        // 2. Commit to the negated public input polynomial.
        BN254.G1Point memory public_comm = public_commitment(
            verifier_index,
            urs,
            public_input
        );

        // 3. Execute fiat-shamir with a Keccak sponge

        Oracles.Result memory oracles_res =
            Oracles.fiat_shamir(proof, verifier_index, public_comm, public_input, true, base_sponge, scalar_sponge);
        Oracles.RandomOracles memory oracles = oracles_res.oracles;

        // 4. Combine the chunked polynomials' evaluations

        //ProofEvaluations memory evals = proof.evals.combine_evals(oracles_res.powers_of_eval_points_for_chunks);
        // INFO: There's only one evaluation per polynomial so there's nothing to combine
        Proof.ProofEvaluations memory evals = proof.evals;

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

        BN254.G1Point memory f_comm = Commitment.msm(commitments, scalars);

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
        columns[0] = Column(ColumnVariant.Z, 0);
        columns[1] = Column(ColumnVariant.Index, GATE_TYPE_GENERIC);
        columns[2] = Column(ColumnVariant.Index, GATE_TYPE_POSEIDON);
        columns[3] = Column(ColumnVariant.Index, GATE_TYPE_COMPLETE_ADD);
        columns[4] = Column(ColumnVariant.Index, GATE_TYPE_VAR_BASE_MUL);
        columns[5] = Column(ColumnVariant.Index, GATE_TYPE_ENDO_MUL);
        columns[6] = Column(ColumnVariant.Index, GATE_TYPE_ENDO_MUL_SCALAR);
        uint256 col_index = 7;
        for (uint256 i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Witness, i);
        }
        for (uint256 i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Coefficient, i);
        }
        for (uint256 i = 0; i < PERMUTS - 1; i++) {
            columns[col_index++] = Column(ColumnVariant.Permutation, i);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, RANGE_CHECK0_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_RANGE_CHECK_0);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, RANGE_CHECK1_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_RANGE_CHECK_1);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, FOREIGN_FIELD_ADD_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_FOREIGN_FIELD_ADD);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, FOREIGN_FIELD_MUL_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_FOREIGN_FIELD_MUL);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, XOR_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_XOR_16);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, ROT_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_ROT_64);
        }
        if (Proof.is_field_set(verifier_index.optional_field_flags, LOOKUP_VERIFIER_INDEX_FLAG)) {
            VerifierIndexLib.LookupVerifierIndex memory li = verifier_index.lookup_index;
            for (uint256 i = 0; i < li.lookup_info.max_per_row + 1; i++) {
                columns[col_index++] = Column(ColumnVariant.LookupSorted, i);
            }
            columns[col_index++] = Column(ColumnVariant.LookupAggreg, 0);
        }
        // push all commitments corresponding to each column
        for (uint256 i = 0; i < col_index; i++) {
            PointEvaluations memory eval = Proof.get_column_eval(proof.evals, columns[i]);
            evaluations[eval_index++] =
                Evaluation(VerifierIndexLib.get_column_commitment(columns[i], verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
        }

        if (Proof.is_field_set(verifier_index.optional_field_flags, LOOKUP_VERIFIER_INDEX_FLAG)) {
            VerifierIndexLib.LookupVerifierIndex memory li = verifier_index.lookup_index;
            if (!Proof.is_field_set(proof.commitments.optional_field_flags, LOOKUP_SORTED_COMM_FLAG)) {
                revert("missing lookup commitments"); // TODO: error
            }
            PointEvaluations memory lookup_evals = proof.evals.lookup_table;
            if (!Proof.is_field_set(proof.evals.optional_field_flags, LOOKUP_TABLE_EVAL_FLAG)) {
                revert("missing lookup table eval");
            }
            PointEvaluations memory lookup_table = proof.evals.lookup_table;

            Scalar.FE joint_combiner = oracles.joint_combiner_field;
            Scalar.FE table_id_combiner = joint_combiner.pow(li.lookup_info.max_joint_size);

            BN254.G1Point memory table_comm = Proof.combine_table(
                li.lookup_table,
                joint_combiner,
                table_id_combiner,
                Proof.is_field_set(li.optional_field_flags, TABLE_IDS_FLAG),
                li.table_ids,
                Proof.is_field_set(proof.commitments.optional_field_flags, LOOKUP_RUNTIME_COMM_FLAG),
                proof.commitments.lookup_runtime
            );

            evaluations[eval_index++] = Evaluation(table_comm, [lookup_table.zeta, lookup_table.zeta_omega], 0);

            if (Proof.is_field_set(li.optional_field_flags, RUNTIME_TABLES_SELECTOR_FLAG)) {
                if (!Proof.is_field_set(proof.commitments.optional_field_flags, LOOKUP_RUNTIME_COMM_FLAG)) {
                    revert("missing lookup runtime commitment");
                }
                BN254.G1Point memory runtime = proof.commitments.lookup_runtime;
                if (!Proof.is_field_set(proof.evals.optional_field_flags, RUNTIME_LOOKUP_TABLE_EVAL_FLAG)) {
                    revert("missing runtime lookup table eval");
                }
                PointEvaluations memory runtime_eval = proof.evals.runtime_lookup_table;

                evaluations[eval_index++] = Evaluation(runtime, [runtime_eval.zeta, runtime_eval.zeta_omega], 0);
            }

            if (Proof.is_field_set(li.optional_field_flags, RUNTIME_TABLES_SELECTOR_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupRuntimeSelector, 0);
                PointEvaluations memory eval = Proof.get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(VerifierIndexLib.get_column_commitment(col, verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
            }
            if (Proof.is_field_set(li.optional_field_flags, XOR_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_XOR);
                PointEvaluations memory eval = Proof.get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(VerifierIndexLib.get_column_commitment(col, verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
            }
            if (Proof.is_field_set(li.optional_field_flags, LOOKUP_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_LOOKUP);
                PointEvaluations memory eval = Proof.get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(VerifierIndexLib.get_column_commitment(col, verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
            }
            if (Proof.is_field_set(li.optional_field_flags, RANGE_CHECK_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_RANGE_CHECK);
                PointEvaluations memory eval = Proof.get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(VerifierIndexLib.get_column_commitment(col, verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
            }
            if (Proof.is_field_set(li.optional_field_flags, FFMUL_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_FOREIGN_FIELD_MUL);
                PointEvaluations memory eval = Proof.get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(VerifierIndexLib.get_column_commitment(col, verifier_index, proof), [eval.zeta, eval.zeta_omega], 0);
            }
        }

        Scalar.FE[2] memory evaluation_points = [oracles.zeta, oracles.zeta.mul(verifier_index.domain_gen)];

        return Proof.AggregatedEvaluationProof(evaluations, evaluation_points, oracles.v, proof.opening);
    }

    function public_commitment(
        VerifierIndexLib.VerifierIndex storage verifier_index,
        Commitment.URS storage urs,
        Scalar.FE public_input
    ) public view returns (BN254.G1Point memory) {
        if (verifier_index.domain_size < verifier_index.max_poly_size) {
            revert PolynomialsAreChunked(verifier_index.domain_size / verifier_index.max_poly_size);
        }

        if (verifier_index.public_len != 1) {
            revert IncorrectPublicInputLength();
        }

        BN254.G1Point memory public_comm;
        BN254.G1Point memory lagrange_base = BN254.G1Point(
            0x280c10e2f52fb4ab3ba21204b30df5b69560978e0911a5c673ad0558070f17c1,
            0x287897da7c8db33cd988a1328770890b2754155612290448267f9ca4c549cb39
        );
        public_comm = lagrange_base.scale_scalar(public_input);
        // negate the results of the MSM
        public_comm = public_comm.neg();

        public_comm = urs.h.add(public_comm);

        return public_comm;
    }

    function perm_scalars(
        Proof.ProofEvaluations memory e,
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
}
