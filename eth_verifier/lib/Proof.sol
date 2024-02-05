// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import "./expr/Expr.sol";
import "./Commitment.sol";
import "./bn254/BN254.sol";
import "./bn254/Fields.sol";

struct PairingProof {
    PolyComm quotient;
    Scalar.FE blinding;
}

struct ProverProof {
    ProofEvaluationsArray evals;
    ProverCommitments commitments;
    PairingProof opening;

    Scalar.FE ft_eval1;
}

struct AggregatedEvaluationProof {
    Scalar.FE[] evaluation_points;
    PairingProof opening;
}

struct ProofEvaluations {
    // public inputs polynomials
    PointEvaluations public_evals;
    bool is_public_evals_set; // public_evals is optional
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
    // evaluation of the EC endoscalar multiplication selector polynomial
    PointEvaluations emul_selector;
    // evaluation of the endoscalar multiplication scalar computation selector polynomial
    PointEvaluations endomul_scalar_selector;

    // Optional gates
    // evaluation of the RangeCheck0 selector polynomial
    PointEvaluations range_check0_selector;
    bool is_range_check0_selector_set;
    // evaluation of the RangeCheck1 selector polynomial
    PointEvaluations range_check1_selector;
    bool is_range_check1_selector_set;
    // evaluation of the ForeignFieldAdd selector polynomial
    PointEvaluations foreign_field_add_selector;
    bool is_foreign_field_add_selector_set;
    // evaluation of the ForeignFieldMul selector polynomial
    PointEvaluations foreign_field_mul_selector;
    bool is_foreign_field_mul_selector_set;
    // evaluation of the Xor selector polynomial
    PointEvaluations xor_selector;
    bool is_xor_selector_set;
    // evaluation of the Rot selector polynomial
    PointEvaluations rot_selector;
    bool is_rot_selector_set;

    // lookup-related evaluations
    // evaluation of lookup aggregation polynomial
    PointEvaluations lookup_aggregation;
    bool is_lookup_aggregation_set;
    // evaluation of lookup table polynomial
    PointEvaluations lookup_table;
    bool is_lookup_table_set;
    // evaluation of lookup sorted polynomials
    PointEvaluations[5] lookup_sorted;
    bool is_lookup_sorted_set;
    // evaluation of runtime lookup table polynomial
    PointEvaluations runtime_lookup_table;
    bool is_runtime_lookup_table_set;

    // lookup selectors
    // evaluation of the runtime lookup table selector polynomial
    PointEvaluations runtime_lookup_table_selector;
    bool is_runtime_lookup_table_selector_set;
    // evaluation of the Xor range check pattern selector polynomial
    PointEvaluations xor_lookup_selector;
    bool is_xor_lookup_selector_set;
    // evaluation of the Lookup range check pattern selector polynomial
    PointEvaluations lookup_gate_lookup_selector;
    bool is_gate_lookup_selector_set;
    // evaluation of the RangeCheck range check pattern selector polynomial
    PointEvaluations range_check_lookup_selector;
    bool is_range_check_lookup_selector_set;
    // evaluation of the ForeignFieldMul range check pattern selector polynomial
    PointEvaluations foreign_field_mul_lookup_selector;
    bool is_foreign_field_mul_lookup_set;
}

struct ProofEvaluationsArray {
    PointEvaluationsArray public_evals;
    bool is_public_evals_set; // public_evals is optional
    // witness polynomials
    PointEvaluationsArray[COLUMNS] w;
    // permutation polynomial
    PointEvaluationsArray z;
    // permutation polynomials
    // (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
    PointEvaluationsArray[PERMUTS - 1] s;
    // coefficient polynomials
    PointEvaluationsArray[COLUMNS] coefficients;
    // evaluation of the generic selector polynomial
    PointEvaluationsArray generic_selector;
    // evaluation of the poseidon selector polynomial
    PointEvaluationsArray poseidon_selector;
    // evaluation of the EC addition selector polynomial
    PointEvaluationsArray complete_add_selector;
    // evaluation of the EC variable base scalar multiplication selector polynomial
    PointEvaluationsArray mul_selector;
    // evaluation of the EC endoscalar multiplication selector polynomial
    PointEvaluationsArray emul_selector;
    // evaluation of the endoscalar multiplication scalar computation selector polynomial
    PointEvaluationsArray endomul_scalar_selector;

    // Optional gates
    // evaluation of the RangeCheck0 selector polynomial
    PointEvaluationsArray range_check0_selector;
    bool is_range_check0_selector_set;
    // evaluation of the RangeCheck1 selector polynomial
    PointEvaluationsArray range_check1_selector;
    bool is_range_check1_selector_set;
    // evaluation of the ForeignFieldAdd selector polynomial
    PointEvaluationsArray foreign_field_add_selector;
    bool is_foreign_field_add_selector_set;
    // evaluation of the ForeignFieldMul selector polynomial
    PointEvaluationsArray foreign_field_mul_selector;
    bool is_foreign_field_mul_selector_set;
    // evaluation of the Xor selector polynomial
    PointEvaluationsArray xor_selector;
    bool is_xor_selector_set;
    // evaluation of the Rot selector polynomial
    PointEvaluationsArray rot_selector;
    bool is_rot_selector_set;

    // lookup-related evaluations
    // evaluation of lookup aggregation polynomial
    PointEvaluationsArray lookup_aggregation;
    bool is_lookup_aggregation_set;
    // evaluation of lookup table polynomial
    PointEvaluationsArray lookup_table;
    bool is_lookup_table_set;
    // evaluation of lookup sorted polynomials
    PointEvaluationsArray[5] lookup_sorted;
    bool is_lookup_sorted_set;
    // evaluation of runtime lookup table polynomial
    PointEvaluationsArray runtime_lookup_table;
    bool is_runtime_lookup_table_set;

    // lookup selectors
    // evaluation of the runtime lookup table selector polynomial
    PointEvaluationsArray runtime_lookup_table_selector;
    bool is_runtime_lookup_table_selector_set;
    // evaluation of the Xor range check pattern selector polynomial
    PointEvaluationsArray xor_lookup_selector;
    bool is_xor_lookup_selector_set;
    // evaluation of the Lookup range check pattern selector polynomial
    PointEvaluationsArray lookup_gate_lookup_selector;
    bool is_gate_lookup_selector_set;
    // evaluation of the RangeCheck range check pattern selector polynomial
    PointEvaluationsArray range_check_lookup_selector;
    bool is_range_check_lookup_selector_set;
    // evaluation of the ForeignFieldMul range check pattern selector polynomial
    PointEvaluationsArray foreign_field_mul_lookup_selector;
    bool is_foreign_field_mul_lookup_set;
}

struct ProverCommitments {
    PolyComm[COLUMNS] w_comm;
    PolyComm z_comm;
    PolyComm t_comm;

    bool is_lookup_set;
    LookupCommitments lookup;
}

struct LookupCommitments {
    PolyComm[] sorted;
    PolyComm aggreg;

    bool is_runtime_set;
    PolyComm runtime; // INFO: optional
}

function combine_evals(ProofEvaluationsArray memory self, PointEvaluations memory pt)
    pure
    returns (ProofEvaluations memory)
{
    PointEvaluations memory public_evals;
    if (self.is_public_evals_set) {
        public_evals = PointEvaluations(
            Polynomial.build_and_eval(self.public_evals.zeta, pt.zeta),
            Polynomial.build_and_eval(self.public_evals.zeta_omega, pt.zeta_omega)
        );
    } else {
        public_evals = PointEvaluations(Scalar.zero(), Scalar.zero());
    }

    PointEvaluations[15] memory w;
    for (uint256 i = 0; i < 15; i++) {
        w[i] = PointEvaluations(
            Polynomial.build_and_eval(self.w[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.w[i].zeta_omega, pt.zeta_omega)
        );
    }

    PointEvaluations memory z;
    z = PointEvaluations(
        Polynomial.build_and_eval(self.z.zeta, pt.zeta), Polynomial.build_and_eval(self.z.zeta_omega, pt.zeta_omega)
    );

    PointEvaluations[7 - 1] memory s;
    for (uint256 i = 0; i < 7 - 1; i++) {
        s[i] = PointEvaluations(
            Polynomial.build_and_eval(self.s[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.s[i].zeta_omega, pt.zeta_omega)
        );
    }

    return ProofEvaluations(public_evals, self.is_public_evals_set, w, z, s);
}

function evaluate_column(ProofEvaluations memory self, Column memory col) pure returns (PointEvaluations memory) {
    if (col.variant == ColumnVariant.Witness) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.w[i];
    }
    if (col.variant == ColumnVariant.Z) {
        return self.z;
    }
    if (col.variant == ColumnVariant.Permutation) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.w[i];
    }
    revert("unhandled column variant");
    // TODO: rest of variants, for this it's necessary to expand ProofEvaluations
}

function evaluate_variable(Variable memory self, ProofEvaluations memory evals) pure returns (Scalar.FE) {
    PointEvaluations memory point_evals = evaluate_column(evals, self.col);
    if (self.row == CurrOrNext.Curr) {
        return point_evals.zeta;
    }
    // self.row == CurrOrNext.Next
    return point_evals.zeta_omega;
}
