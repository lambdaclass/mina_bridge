// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import "./expr/Expr.sol";
import "./Commitment.sol";
import "./bn254/BN254.sol";
import "./bn254/Fields.sol";

error MissingIndexEvaluation(string col);
error MissingColumnEvaluation(ColumnVariant variant);
error MissingLookupColumnEvaluation(LookupPattern pattern);
error MissingIndexColumnEvaluation(GateType gate);

using {Scalar.mul} for Scalar.FE;

struct PairingProof {
    PolyComm quotient;
    Scalar.FE blinding;
}

struct NewPairingProof {
    BN254.G1Point quotient;
    Scalar.FE blinding;
}

struct ProverProof {
    ProofEvaluationsArray evals;
    ProverCommitments commitments;
    PairingProof opening;
    Scalar.FE ft_eval1;
}

struct AggregatedEvaluationProof {
    Evaluation[] evaluations;
    Scalar.FE[2] evaluation_points;
    Scalar.FE polyscale;
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
    bool is_lookup_gate_lookup_selector_set;
    // evaluation of the RangeCheck range check pattern selector polynomial
    PointEvaluations range_check_lookup_selector;
    bool is_range_check_lookup_selector_set;
    // evaluation of the ForeignFieldMul range check pattern selector polynomial
    PointEvaluations foreign_field_mul_lookup_selector;
    bool is_foreign_field_mul_lookup_selector_set;
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
    // evaluation of the EC endoscalar  emultiplication selector polynomial
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
    bool is_lookup_gate_lookup_selector_set;
    // evaluation of the RangeCheck range check pattern selector polynomial
    PointEvaluationsArray range_check_lookup_selector;
    bool is_range_check_lookup_selector_set;
    // evaluation of the ForeignFieldMul range check pattern selector polynomial
    PointEvaluationsArray foreign_field_mul_lookup_selector;
    bool is_foreign_field_mul_lookup_selector_set;
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

function combine_evals(
    ProofEvaluationsArray memory self,
    PointEvaluations memory pt
) pure returns (ProofEvaluations memory evals) {
    // public evals
    if (self.is_public_evals_set) {
        evals.public_evals = PointEvaluations(
            Polynomial.build_and_eval(self.public_evals.zeta, pt.zeta),
            Polynomial.build_and_eval(
                self.public_evals.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_public_evals_set = true;
    } else {
        evals.public_evals = PointEvaluations(Scalar.zero(), Scalar.zero());
    }
    // w
    for (uint256 i = 0; i < evals.w.length; i++) {
        evals.w[i] = PointEvaluations(
            Polynomial.build_and_eval(self.w[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.w[i].zeta_omega, pt.zeta_omega)
        );
    }
    // z
    evals.z = PointEvaluations(
        Polynomial.build_and_eval(self.z.zeta, pt.zeta),
        Polynomial.build_and_eval(self.z.zeta_omega, pt.zeta_omega)
    );
    // s
    for (uint256 i = 0; i < evals.s.length; i++) {
        evals.s[i] = PointEvaluations(
            Polynomial.build_and_eval(self.s[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.s[i].zeta_omega, pt.zeta_omega)
        );
    }
    // coefficients
    for (uint256 i = 0; i < evals.coefficients.length; i++) {
        evals.coefficients[i] = PointEvaluations(
            Polynomial.build_and_eval(self.coefficients[i].zeta, pt.zeta),
            Polynomial.build_and_eval(
                self.coefficients[i].zeta_omega,
                pt.zeta_omega
            )
        );
    }
    // generic_selector
    evals.generic_selector = PointEvaluations(
        Polynomial.build_and_eval(self.generic_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(
            self.generic_selector.zeta_omega,
            pt.zeta_omega
        )
    );
    // poseidon_selector
    evals.poseidon_selector = PointEvaluations(
        Polynomial.build_and_eval(self.poseidon_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(
            self.poseidon_selector.zeta_omega,
            pt.zeta_omega
        )
    );
    // complete_add_selector
    evals.complete_add_selector = PointEvaluations(
        Polynomial.build_and_eval(self.complete_add_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(
            self.complete_add_selector.zeta_omega,
            pt.zeta_omega
        )
    );
    // mul_selector
    evals.mul_selector = PointEvaluations(
        Polynomial.build_and_eval(self.mul_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(self.mul_selector.zeta_omega, pt.zeta_omega)
    );
    // emul_selector
    evals.emul_selector = PointEvaluations(
        Polynomial.build_and_eval(self.emul_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(self.emul_selector.zeta_omega, pt.zeta_omega)
    );
    // endomul_scalar_selector
    evals.endomul_scalar_selector = PointEvaluations(
        Polynomial.build_and_eval(self.endomul_scalar_selector.zeta, pt.zeta),
        Polynomial.build_and_eval(
            self.endomul_scalar_selector.zeta_omega,
            pt.zeta_omega
        )
    );

    // range_check0_selector
    if (self.is_range_check0_selector_set) {
        evals.range_check0_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.range_check0_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.range_check0_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_range_check0_selector_set = true;
    }
    // range_check1_selector
    if (self.is_range_check1_selector_set) {
        evals.range_check1_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.range_check1_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.range_check1_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_range_check1_selector_set = true;
    }
    // foreign_field_add_selector
    if (self.is_foreign_field_add_selector_set) {
        evals.foreign_field_add_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.foreign_field_add_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.foreign_field_add_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_foreign_field_add_selector_set = true;
    }
    // foreign_field_mul_selector
    if (self.is_foreign_field_mul_selector_set) {
        evals.foreign_field_mul_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.foreign_field_mul_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.foreign_field_mul_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_foreign_field_mul_selector_set = true;
    }
    // xor_selector
    if (self.is_xor_selector_set) {
        evals.xor_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.xor_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.xor_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_xor_selector_set = true;
    }
    // rot_selector
    if (self.is_rot_selector_set) {
        evals.rot_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.rot_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.rot_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_rot_selector_set = true;
    }

    // lookup_aggregation
    if (self.is_lookup_aggregation_set) {
        evals.lookup_aggregation = PointEvaluations(
            Polynomial.build_and_eval(
                self.lookup_aggregation.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.lookup_aggregation.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_lookup_aggregation_set = true;
    }
    // lookup_table
    if (self.is_lookup_table_set) {
        evals.lookup_table = PointEvaluations(
            Polynomial.build_and_eval(
                self.lookup_table.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.lookup_table.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_lookup_table_set = true;
    }
    // lookup_sorted
    if (self.is_lookup_sorted_set) {
        for (uint256 i = 0; i < evals.lookup_sorted.length; i++) {
            evals.lookup_sorted[i] = PointEvaluations(
                Polynomial.build_and_eval(self.lookup_sorted[i].zeta, pt.zeta),
                Polynomial.build_and_eval(
                    self.lookup_sorted[i].zeta_omega,
                    pt.zeta_omega
                )
            );
            evals.is_lookup_sorted_set = true;
        }
    }
    // runtime_lookup_table
    if (self.is_runtime_lookup_table_set) {
        evals.runtime_lookup_table = PointEvaluations(
            Polynomial.build_and_eval(
                self.runtime_lookup_table.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.runtime_lookup_table.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_runtime_lookup_table_set = true;
    }

    // runtime_lookup_table_selector
    if (self.is_runtime_lookup_table_selector_set) {
        evals.runtime_lookup_table_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.runtime_lookup_table_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.runtime_lookup_table_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_runtime_lookup_table_selector_set = true;
    }

    // xor_lookup_selector
    if (self.is_xor_lookup_selector_set) {
        evals.xor_lookup_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.xor_lookup_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.xor_lookup_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_xor_lookup_selector_set = true;
    }

    // lookup_gate_lookup_selector
    if (self.is_lookup_gate_lookup_selector_set) {
        evals.lookup_gate_lookup_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.lookup_gate_lookup_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.lookup_gate_lookup_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_lookup_gate_lookup_selector_set = true;
    }

    // range_check_lookup_selector
    if (self.is_range_check_lookup_selector_set) {
        evals.range_check_lookup_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.range_check_lookup_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.range_check_lookup_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_range_check_lookup_selector_set = true;
    }

    // foreign_field_mul_lookup_selector
    if (self.is_foreign_field_mul_lookup_selector_set) {
        evals.foreign_field_mul_lookup_selector = PointEvaluations(
            Polynomial.build_and_eval(
                self.foreign_field_mul_lookup_selector.zeta,
                pt.zeta
            ),
            Polynomial.build_and_eval(
                self.foreign_field_mul_lookup_selector.zeta_omega,
                pt.zeta_omega
            )
        );
        evals.is_foreign_field_mul_lookup_selector_set = true;
    }
}

// INFO: ref: berkeley_columns.rs
function evaluate_column(
    ProofEvaluations memory self,
    Column memory col
) view returns (PointEvaluations memory) {
    if (col.variant == ColumnVariant.Witness) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.w[i];
    }
    if (col.variant == ColumnVariant.Z) {
        return self.z;
    }
    if (col.variant == ColumnVariant.LookupSorted) {
        if (!self.is_lookup_sorted_set) {
            revert MissingIndexEvaluation("lookup_sorted");
        }
        uint256 i = abi.decode(col.data, (uint256));
        return self.lookup_sorted[i];
    }
    if (col.variant == ColumnVariant.LookupAggreg) {
        if (!self.is_lookup_aggregation_set) {
            revert MissingIndexEvaluation("lookup_aggregation");
        }
        return self.lookup_aggregation;
    }
    if (col.variant == ColumnVariant.LookupTable) {
        if (!self.is_lookup_table_set) {
            revert MissingIndexEvaluation("lookup_table");
        }
        return self.lookup_table;
    }
    if (col.variant == ColumnVariant.LookupRuntimeTable) {
        if (!self.is_runtime_lookup_table_set) {
            revert MissingIndexEvaluation("runtime_lookup_table");
        }
        return self.runtime_lookup_table;
    }
    if (col.variant == ColumnVariant.Index) {
        GateType gate_type = abi.decode(col.data, (GateType));
        if (gate_type == GateType.Poseidon) {
            return self.poseidon_selector;
        }
        if (gate_type == GateType.Generic) {
            return self.generic_selector;
        }
        if (gate_type == GateType.CompleteAdd) {
            return self.complete_add_selector;
        }
        if (gate_type == GateType.VarBaseMul) {
            return self.mul_selector;
        }
        if (gate_type == GateType.EndoMul) {
            return self.emul_selector;
        }
        if (gate_type == GateType.EndoMulScalar) {
            return self.endomul_scalar_selector;
        }
        if (gate_type == GateType.RangeCheck0) {
            if (!self.is_range_check0_selector_set) {
                revert MissingIndexEvaluation("range_check0_selector");
            }
            return self.range_check0_selector;
        }
        if (gate_type == GateType.RangeCheck1) {
            if (!self.is_range_check1_selector_set) {
                revert MissingIndexEvaluation("range_check1_selector");
            }
            return self.range_check1_selector;
        }
        if (gate_type == GateType.ForeignFieldAdd) {
            if (!self.is_foreign_field_add_selector_set) {
                revert MissingIndexEvaluation("foreign_field_add_selector");
            }
            return self.foreign_field_add_selector;
        }
        if (gate_type == GateType.ForeignFieldMul) {
            if (!self.is_foreign_field_mul_selector_set) {
                revert MissingIndexEvaluation("foreign_field_mul_selector");
            }
            return self.foreign_field_mul_selector;
        }
        if (gate_type == GateType.Xor16) {
            if (!self.is_xor_selector_set) {
                revert MissingIndexEvaluation("xor_selector");
            }
            return self.xor_selector;
        }
        if (gate_type == GateType.Rot64) {
            if (!self.is_rot_selector_set) {
                revert MissingIndexEvaluation("rot_selector");
            }
            return self.rot_selector;
        }
    }
    if (col.variant == ColumnVariant.Permutation) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.s[i];
    }
    if (col.variant == ColumnVariant.Coefficient) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.coefficients[i];
    }
    if (col.variant == ColumnVariant.LookupKindIndex) {
        LookupPattern pattern = abi.decode(col.data, (LookupPattern));
        if (pattern == LookupPattern.Xor) {
            if (!self.is_xor_lookup_selector_set) {
                revert MissingIndexEvaluation("xor_lookup_selector");
            }
            return self.xor_lookup_selector;
        }
        if (pattern == LookupPattern.Lookup) {
            if (!self.is_lookup_gate_lookup_selector_set) {
                revert MissingIndexEvaluation("lookup_gate_lookup_selector");
            }
            return self.lookup_gate_lookup_selector;
        }
        if (pattern == LookupPattern.RangeCheck) {
            if (!self.is_range_check_lookup_selector_set) {
                revert MissingIndexEvaluation("range_check_lookup_selector");
            }
            return self.range_check_lookup_selector;
        }
        if (pattern == LookupPattern.ForeignFieldMul) {
            if (!self.is_foreign_field_mul_lookup_selector_set) {
                revert MissingIndexEvaluation(
                    "foreign_field_mul_lookup_selector"
                );
            }
            return self.foreign_field_mul_lookup_selector;
        }
    }
    if (col.variant == ColumnVariant.LookupRuntimeSelector) {
        if (!self.is_runtime_lookup_table_selector_set) {
            revert MissingIndexEvaluation("runtime_lookup_table_selector");
        }
        return self.runtime_lookup_table_selector;
    }
    revert("unhandled column variant");
}

function evaluate_variable(
    Variable memory self,
    ProofEvaluations memory evals
) view returns (Scalar.FE) {
    PointEvaluations memory point_evals = evaluate_column(evals, self.col);
    if (self.row == CurrOrNext.Curr) {
        return point_evals.zeta;
    }
    // self.row == CurrOrNext.Next
    return point_evals.zeta_omega;
}

function get_column_eval(
    ProofEvaluationsArray memory evals,
    Column memory col
) pure returns (PointEvaluationsArray memory) {
    ColumnVariant variant = col.variant;
    bytes memory data = col.data;
    if (variant == ColumnVariant.Witness) {
        uint256 i = abi.decode(data, (uint256));
        return evals.w[i];
    } else if (variant == ColumnVariant.Z) {
        return evals.z;
    } else if (variant == ColumnVariant.LookupSorted) {
        uint256 i = abi.decode(data, (uint256));
        return evals.lookup_sorted[i];
    } else if (variant == ColumnVariant.LookupAggreg) {
        return evals.lookup_aggregation;
    } else if (variant == ColumnVariant.LookupTable) {
        return evals.lookup_table;
    } else if (variant == ColumnVariant.LookupKindIndex) {
        LookupPattern pattern = abi.decode(data, (LookupPattern));
        if (pattern == LookupPattern.Xor) { return evals.xor_lookup_selector; }
        else if (pattern == LookupPattern.Lookup) { return evals.lookup_gate_lookup_selector; }
        else if (pattern == LookupPattern.RangeCheck) { return evals.range_check_lookup_selector; }
        else if (pattern == LookupPattern.ForeignFieldMul) { return evals.foreign_field_mul_lookup_selector; }
        else { revert MissingLookupColumnEvaluation(pattern); }
    } else if (variant == ColumnVariant.LookupRuntimeSelector) {
        return evals.runtime_lookup_table_selector;
    } else if (variant == ColumnVariant.Index) {
        GateType gate = abi.decode(data, (GateType));
        if (gate == GateType.Generic) { return evals.generic_selector; }
        else if (gate == GateType.Poseidon) { return evals.poseidon_selector; } 
        else if (gate == GateType.CompleteAdd) { return evals.complete_add_selector; } 
        else if (gate == GateType.VarBaseMul) { return evals.mul_selector; }
        else if (gate == GateType.EndoMul) { return evals.emul_selector; } 
        else if (gate == GateType.EndoMulScalar) { return evals.endomul_scalar_selector; }
        else if (gate == GateType.RangeCheck0) { return evals.range_check0_selector; }
        else if (gate == GateType.RangeCheck1) { return evals.range_check1_selector; }
        else if (gate == GateType.ForeignFieldAdd) { return evals.foreign_field_add_selector; }
        else if (gate == GateType.ForeignFieldMul) { return evals.foreign_field_mul_selector; }
        else if (gate == GateType.Xor16) { return evals.xor_selector; }
        else if (gate == GateType.Rot64) { return evals.rot_selector; }
        else { revert MissingIndexColumnEvaluation(gate); }
    } else if (variant == ColumnVariant.Coefficient) {
        uint256 i = abi.decode(data, (uint256));
        return evals.coefficients[i];
    } else if (variant == ColumnVariant.Permutation) {
        uint256 i = abi.decode(data, (uint256));
        return evals.s[i];
    } else {
        revert MissingColumnEvaluation(variant);
    }
}
function combine_table(
    PolyComm[] memory columns,
    Scalar.FE column_combiner,
    Scalar.FE table_id_combiner,
    bool is_table_id_vector_set,
    PolyComm memory table_id_vector,
    bool is_runtime_vector_set,
    PolyComm memory runtime_vector
) view returns (PolyComm memory) {
    require(columns.length != 0, "column commitments are empty");
    uint256 total_len = columns.length
        + (is_table_id_vector_set ? 1 : 0)
        + (is_runtime_vector_set ? 1 : 0);

    Scalar.FE j = Scalar.one();
    Scalar.FE[] memory scalars = new Scalar.FE[](total_len);
    PolyComm[] memory commitments = new PolyComm[](total_len);

    uint256 index = 0;

    scalars[index] = j;
    commitments[index] = columns[0];
    index += 1;
    for (uint i = 1; i < columns.length; i++) {
        j = j.mul(column_combiner);
        scalars[index] = j;
        commitments[index] = columns[i];
        index += 1;
    }

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

    return polycomm_msm(commitments, scalars);
}
