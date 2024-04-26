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
using {sub_polycomms, scale_polycomm} for PolyComm;
using {Proof.get_column_eval} for Proof.ProofEvaluations;

library KimchiPartialVerifier {
    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);

    // This takes Kimchi's `to_batch()` as reference.
    function partial_verify(
        ProverProof storage proof,
        VerifierIndex storage verifier_index,
        URS storage urs,
        Scalar.FE public_input,
        uint256[] storage lagrange_bases_components, // flattened pairs of (x, y) coords
        Sponge storage base_sponge,
        Sponge storage scalar_sponge
    ) external returns (AggregatedEvaluationProof memory) {
        // TODO: 1. CHeck the length of evaluations insde the proof

        // 2. Commit to the negated public input polynomial.
        BN254.G1Point memory public_comm = public_commitment(
            verifier_index,
            urs,
            public_input,
            lagrange_bases_components
        );

        // 3. Execute fiat-shamir with a Keccak sponge

        Oracles.Result memory oracles_res =
            Oracles.fiat_shamir(proof, verifier_index, public_comm, public_input, true, base_sponge, scalar_sponge);
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

            evaluations[eval_index++] = Evaluation(table_comm, [lookup_table.zeta, lookup_table.zeta_omega], 0);

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


    function public_commitment(
        VerifierIndex storage verifier_index,
        URS storage urs,
        Scalar.FE public_input,
        uint256[] storage lagrange_bases_components // flattened pairs of (x, y) coords
    ) public view returns (BN254.G1Point memory) {
        if (verifier_index.domain_size < verifier_index.max_poly_size) {
            revert PolynomialsAreChunked(verifier_index.domain_size / verifier_index.max_poly_size);
        }

        if (verifier_index.public_len != 1) {
            revert IncorrectPublicInputLength();
        }
        BN254.G1Point memory public_comm;
        BN254.G1Point memory lagrange_base = BN254.G1Point(
                lagrange_bases_components[0],
                lagrange_bases_components[1]
            );
        public_comm = lagrange_base.scale_scalar(public_input);
        // negate the results of the MSM
        public_comm = public_comm.neg();

        public_comm = urs.h.add(public_comm);

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
}
