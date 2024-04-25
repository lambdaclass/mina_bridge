// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import "./expr/Expr.sol";
import "./Commitment.sol";
import "./bn254/BN254.sol";
import "./bn254/Fields.sol";
import "./VerifierIndex.sol";

error MissingIndexEvaluation(string col);
error MissingColumnEvaluation(ColumnVariant variant);
error MissingLookupColumnEvaluation(uint256 inner);
error MissingIndexColumnEvaluation(uint256 inner);
error UnhandledColumnVariant(uint256 id);

using {Scalar.mul} for Scalar.FE;

struct PairingProof {
    BN254.G1Point quotient;
    Scalar.FE blinding;
}

struct ProverProof {
    ProverCommitments commitments;
    PairingProof opening;
    ProofEvaluations evals;
    Scalar.FE ft_eval1;
}

struct AggregatedEvaluationProof {
    Evaluation[] evaluations;
    Scalar.FE[2] evaluation_points;
    Scalar.FE polyscale;
    PairingProof opening;
}

struct ProofEvaluations {
    // each bit represents the presence (1) or absence (0) of an
    // optional field.
    uint256 optional_field_flags;
    // witness polynomials
    PointEvaluations[COLUMNS] w;
    // permutation polynomial
    PointEvaluations z;
    // permutation polynomials
    // (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
    PointEvaluations[PERMUTS - 1] s;
    // coefficient polynomials
    PointEvaluations[COLUMNS] coefficients;
    // evaluation of the generic selector polynomial
    PointEvaluations generic_selector;
    // evaluation of the poseidon selector polynomial
    PointEvaluations poseidon_selector;
    // evaluation of the EC addition selector polynomial
    PointEvaluations complete_add_selector;
    // evaluation of the EC variable base scalar multiplication selector polynomial
    PointEvaluations mul_selector;
    // evaluation of the EC endoscalar  emultiplication selector polynomial
    PointEvaluations emul_selector;
    // evaluation of the endoscalar multiplication scalar computation selector polynomial
    PointEvaluations endomul_scalar_selector;
    // Optional gates
    PointEvaluations public_evals;
    // evaluation of the RangeCheck0 selector polynomial
    PointEvaluations range_check0_selector;
    // evaluation of the RangeCheck1 selector polynomial
    PointEvaluations range_check1_selector;
    // evaluation of the ForeignFieldAdd selector polynomial
    PointEvaluations foreign_field_add_selector;
    // evaluation of the ForeignFieldMul selector polynomial
    PointEvaluations foreign_field_mul_selector;
    // evaluation of the Xor selector polynomial
    PointEvaluations xor_selector;
    // evaluation of the Rot selector polynomial
    PointEvaluations rot_selector;
    // lookup-related evaluations
    // evaluation of lookup aggregation polynomial
    PointEvaluations lookup_aggregation;
    // evaluation of lookup table polynomial
    PointEvaluations lookup_table;
    // evaluation of lookup sorted polynomials
    PointEvaluations[5] lookup_sorted;
    // evaluation of runtime lookup table polynomial
    PointEvaluations runtime_lookup_table;
    // lookup selectors
    // evaluation of the runtime lookup table selector polynomial
    PointEvaluations runtime_lookup_table_selector;
    // evaluation of the Xor range check pattern selector polynomial
    PointEvaluations xor_lookup_selector;
    // evaluation of the Lookup range check pattern selector polynomial
    PointEvaluations lookup_gate_lookup_selector;
    // evaluation of the RangeCheck range check pattern selector polynomial
    PointEvaluations range_check_lookup_selector;
    // evaluation of the ForeignFieldMul range check pattern selector polynomial
    PointEvaluations foreign_field_mul_lookup_selector;
}

struct ProverCommitments {
    uint256 optional_field_flags;
    BN254.G1Point[COLUMNS] w_comm;
    BN254.G1Point z_comm;
    BN254.G1Point[7] t_comm;
    // optional commitments
    BN254.G1Point[] lookup_sorted;
    BN254.G1Point lookup_aggreg;
    BN254.G1Point lookup_runtime;
}

function evaluate_column_by_id(ProofEvaluations memory self, uint256 col_id) view returns (PointEvaluations memory) {
    if (col_id <= 14) {
        return self.w[col_id];
    } else if (col_id == 15) {
        return self.z;
    } else if (col_id <= 20) {
        uint256 i = col_id - 16;
        if (!is_field_set(self, LOOKUP_SORTED_EVAL_FLAG + i)) {
            revert MissingIndexEvaluation("lookup_sorted");
        }
        return self.lookup_sorted[i];
    } else if (col_id == 21) {
        if (!is_field_set(self, LOOKUP_AGGREGATION_EVAL_FLAG)) {
            revert MissingIndexEvaluation("lookup_aggregation");
        }
        return self.lookup_aggregation;
    } else if (col_id == 22) {
        if (!is_field_set(self, LOOKUP_TABLE_EVAL_FLAG)) {
            revert MissingIndexEvaluation("lookup_table");
        }
        return self.lookup_table;
    } else if (col_id == 23) {
        if (!is_field_set(self, XOR_LOOKUP_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("xor_lookup_selector");
        }
        return self.xor_lookup_selector;
    } else if (col_id == 24) {
        if (!is_field_set(self, LOOKUP_GATE_LOOKUP_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("lookup_gate_lookup_selector");
        }
        return self.lookup_gate_lookup_selector;
    } else if (col_id == 25) {
        if (!is_field_set(self, RANGE_CHECK_LOOKUP_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("range_check_lookup_selector");
        }
        return self.range_check_lookup_selector;
    } else if (col_id == 26) {
        if (!is_field_set(self, FOREIGN_FIELD_MUL_LOOKUP_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("foreign_field_mul_lookup_selector");
        }
        return self.foreign_field_mul_lookup_selector;
    } else if (col_id == 27) {
        if (!is_field_set(self, RUNTIME_LOOKUP_TABLE_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("runtime_lookup_table_selector");
        }
        return self.runtime_lookup_table_selector;
    } else if (col_id == 28) {
        if (!is_field_set(self, RUNTIME_LOOKUP_TABLE_EVAL_FLAG)) {
            revert MissingIndexEvaluation("runtime_lookup_table");
        }
        return self.runtime_lookup_table;
    } else if (col_id == 30) {
        return self.generic_selector;
    } else if (col_id == 31) {
        return self.poseidon_selector;
    } else if (col_id == 32) {
        return self.complete_add_selector;
    } else if (col_id == 33) {
        return self.mul_selector;
    } else if (col_id == 34) {
        return self.emul_selector;
    } else if (col_id == 35) {
        return self.endomul_scalar_selector;
    } else if (col_id == 37) {
        if (!is_field_set(self, RANGE_CHECK0_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("range_check0_selector");
        }
        return self.range_check0_selector;
    } else if (col_id == 38) {
        if (!is_field_set(self, RANGE_CHECK1_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("range_check1_selector");
        }
        return self.range_check1_selector;
    } else if (col_id == 39) {
        if (!is_field_set(self, FOREIGN_FIELD_ADD_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("foreign_field_add_selector");
        }
        return self.foreign_field_add_selector;
    } else if (col_id == 40) {
        if (!is_field_set(self, FOREIGN_FIELD_MUL_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("foreign_field_mul_selector");
        }
        return self.foreign_field_mul_selector;
    } else if (col_id == 41) {
        if (!is_field_set(self, XOR_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("xor_selector");
        }
        return self.xor_selector;
    } else if (col_id == 42) {
        if (!is_field_set(self, ROT_SELECTOR_EVAL_FLAG)) {
            revert MissingIndexEvaluation("rot_selector");
        }
        return self.rot_selector;
    } else if (col_id <= 57) {
        return self.coefficients[col_id - 43];
    } else if (col_id <= 63) {
        return self.s[col_id - 58];
    } else {
        revert UnhandledColumnVariant(col_id);
    }
}

function combine_table(
    BN254.G1Point memory column,
    Scalar.FE column_combiner,
    Scalar.FE table_id_combiner,
    bool is_table_id_vector_set,
    BN254.G1Point memory table_id_vector,
    bool is_runtime_vector_set,
    BN254.G1Point memory runtime_vector
) view returns (BN254.G1Point memory) {
    uint256 total_len = 1 + (is_table_id_vector_set ? 1 : 0) + (is_runtime_vector_set ? 1 : 0);

    Scalar.FE j = Scalar.one();
    Scalar.FE[] memory scalars = new Scalar.FE[](total_len);
    BN254.G1Point[] memory commitments = new BN254.G1Point[](total_len);

    uint256 index = 0;

    scalars[index] = j;
    commitments[index] = column;
    index += 1;

    if (is_table_id_vector_set) {
        scalars[index] = table_id_combiner;
        commitments[index] = table_id_vector;
        index += 1;
    }
    if (is_runtime_vector_set) {
        scalars[index] = column_combiner;
        commitments[index] = runtime_vector;
        index += 1;
    }

    return msm(commitments, scalars);
}

function is_field_set(ProofEvaluations memory self, uint256 flag_pos) pure returns (bool) {
    return (self.optional_field_flags >> flag_pos) & 1 == 1;
}

function is_field_set(ProverCommitments memory self, uint256 flag_pos) pure returns (bool) {
    return (self.optional_field_flags >> flag_pos) & 1 == 1;
}

function is_field_set(VerifierIndex storage self, uint256 flag_pos) view returns (bool) {
    return (self.optional_field_flags >> flag_pos) & 1 == 1;
}

function is_field_set(LookupVerifierIndex memory self, uint256 flag_pos) pure returns (bool) {
    return (self.optional_field_flags >> flag_pos) & 1 == 1;
}
