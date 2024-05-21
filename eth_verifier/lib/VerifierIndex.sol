// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {BN254} from "./bn254/BN254.sol";
import {Scalar} from "./bn254/Fields.sol";
import {Alphas} from "./Alphas.sol";
import {KeccakSponge} from "./sponge/Sponge.sol";
import {ColumnVariant} from "./expr/Expr.sol";
import {Proof} from "./Proof.sol";
import {Linearization, Column} from "./expr/Expr.sol";
import {Base} from "./bn254/Fields.sol";
import {
    LOOKUP_RUNTIME_COMM_FLAG,
    RANGE_CHECK0_COMM_FLAG,
    RANGE_CHECK1_COMM_FLAG,
    FOREIGN_FIELD_ADD_COMM_FLAG,
    FOREIGN_FIELD_MUL_COMM_FLAG,
    XOR_COMM_FLAG,
    ROT_COMM_FLAG,
    LOOKUP_VERIFIER_INDEX_FLAG,
    XOR_FLAG,
    LOOKUP_FLAG,
    RANGE_CHECK_FLAG,
    FFMUL_FLAG,
    TABLE_IDS_FLAG,
    RUNTIME_TABLES_SELECTOR_FLAG,
    GATE_TYPE_GENERIC,
    GATE_TYPE_POSEIDON,
    GATE_TYPE_COMPLETE_ADD,
    GATE_TYPE_VAR_BASE_MUL,
    GATE_TYPE_ENDO_MUL,
    GATE_TYPE_ENDO_MUL_SCALAR,
    GATE_TYPE_RANGE_CHECK_0,
    GATE_TYPE_RANGE_CHECK_1,
    GATE_TYPE_FOREIGN_FIELD_ADD,
    GATE_TYPE_FOREIGN_FIELD_MUL,
    GATE_TYPE_XOR_16,
    GATE_TYPE_ROT_64,
    LOOKUP_PATTERN_XOR,
    LOOKUP_PATTERN_LOOKUP,
    LOOKUP_PATTERN_RANGE_CHECK,
    LOOKUP_PATTERN_FOREIGN_FIELD_MUL
} from "./Constants.sol";

using {
    KeccakSponge.reinit,
    KeccakSponge.absorb_base,
    KeccakSponge.absorb_scalar,
    KeccakSponge.absorb_scalar_multiple,
    KeccakSponge.absorb_evaluations,
    KeccakSponge.absorb_g,
    KeccakSponge.absorb_g_single,
    KeccakSponge.challenge_base,
    KeccakSponge.challenge_scalar,
    KeccakSponge.digest_base,
    KeccakSponge.digest_scalar
} for KeccakSponge.Sponge;

error MissingCommitment(ColumnVariant variant);
error MissingLookupColumnCommitment(uint256 inner);
error MissingIndexColumnCommitment(uint256 inner);

library VerifierIndexLib {
    struct VerifierIndex {
        // each bit represents the presence (1) or absence (0) of an
        // optional field.
        uint256 optional_field_flags;
        // domain
        uint256 domain_size;
        Scalar.FE domain_gen;
        // maximal size of polynomial section
        uint256 max_poly_size;
        // the number of randomized rows to achieve zero knowledge
        uint256 zk_rows;
        // number of public inputs
        uint256 public_len;
        // polynomial commitments

        // permutation commitment array
        BN254.G1Point[7] sigma_comm; // TODO: use Constants.PERMUTS
        // coefficient commitment array
        BN254.G1Point[15] coefficients_comm; // TODO: use Constants.COLUMNS
        // TODO: doc
        BN254.G1Point generic_comm;
        // poseidon constraint selector polynomial commitment
        BN254.G1Point psm_comm;
        // ECC arithmetic polynomial commitments

        // EC addition selector polynomial commitment
        BN254.G1Point complete_add_comm;
        // EC variable base scalar multiplication selector polynomial commitment
        BN254.G1Point mul_comm;
        // endoscalar multiplication selector polynomial commitment
        BN254.G1Point emul_comm;
        // endoscalar multiplication scalar computation selector polynomial commitment
        BN254.G1Point endomul_scalar_comm;
        // wire shift coordinates
        Scalar.FE[7] shift; // TODO: use Consants.PERMUTS
        /// domain offset for zero-knowledge
        Scalar.FE w;
        Scalar.FE endo;
        // RangeCheck0 polynomial commitments
        BN254.G1Point range_check0_comm; // INFO: optional
        // RangeCheck1 polynomial commitments
        BN254.G1Point range_check1_comm; // INFO: optional
        // Foreign field addition gates polynomial commitments
        BN254.G1Point foreign_field_add_comm; // INFO: optional
        // Foreign field multiplication gates polynomial commitments
        BN254.G1Point foreign_field_mul_comm; // INFO: optional
        // Xor commitments
        BN254.G1Point xor_comm; // INFO: optional
        // Rot commitments
        BN254.G1Point rot_comm; // INFO: optional
        LookupVerifierIndex lookup_index; // INFO: optional
        // this is used for generating the index's digest
        Linearization linearization;
        /// The mapping between powers of alpha and constraints
        Alphas powers_of_alpha;
    }

    struct LookupVerifierIndex {
        // each bit represents the presence (1) or absence (0) of an
        // optional field.
        uint256 optional_field_flags;
        BN254.G1Point lookup_table;
        LookupInfo lookup_info;
        // selectors
        BN254.G1Point xor; // INFO: optional
        BN254.G1Point lookup; // INFO: optional
        BN254.G1Point range_check; // INFO: optional
        BN254.G1Point ffmul; // INFO: optional
        // table IDs for the lookup values.
        // this may be not set if all lookups originate from table 0.
        BN254.G1Point table_ids; // INFO: optional
        // an optional selector polynomial for runtime tables
        BN254.G1Point runtime_tables_selector; // INFO: optional
    }

    struct LookupSelectors {
        BN254.G1Point xor; // INFO: optional
        BN254.G1Point lookup; // INFO: optional
        BN254.G1Point range_check; // INFO: optional
        BN254.G1Point ffmul; // INFO: optional
    }

    struct LookupInfo {
        uint256 max_per_row;
        uint256 max_joint_size;
    }
    // TODO: lookup features

    function verifier_digest(VerifierIndex storage index) internal view returns (Base.FE) {
        KeccakSponge.Sponge memory sponge;
        sponge.reinit();

        for (uint256 i = 0; i < index.sigma_comm.length; i++) {
            sponge.absorb_g_single(index.sigma_comm[i]);
        }
        for (uint256 i = 0; i < index.coefficients_comm.length; i++) {
            sponge.absorb_g_single(index.coefficients_comm[i]);
        }
        sponge.absorb_g_single(index.generic_comm);
        sponge.absorb_g_single(index.psm_comm);
        sponge.absorb_g_single(index.complete_add_comm);
        sponge.absorb_g_single(index.mul_comm);
        sponge.absorb_g_single(index.emul_comm);
        sponge.absorb_g_single(index.endomul_scalar_comm);

        // optional

        if (Proof.is_field_set(index.optional_field_flags, RANGE_CHECK0_COMM_FLAG)) {
            sponge.absorb_g_single(index.range_check0_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, RANGE_CHECK1_COMM_FLAG)) {
            sponge.absorb_g_single(index.range_check1_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, FOREIGN_FIELD_MUL_COMM_FLAG)) {
            sponge.absorb_g_single(index.foreign_field_mul_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, FOREIGN_FIELD_ADD_COMM_FLAG)) {
            sponge.absorb_g_single(index.foreign_field_add_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, XOR_COMM_FLAG)) {
            sponge.absorb_g_single(index.xor_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, ROT_COMM_FLAG)) {
            sponge.absorb_g_single(index.rot_comm);
        }

        if (Proof.is_field_set(index.optional_field_flags, LOOKUP_VERIFIER_INDEX_FLAG)) {
            LookupVerifierIndex storage l_index = index.lookup_index;
            sponge.absorb_g_single(l_index.lookup_table);
            if (Proof.is_field_set(l_index.optional_field_flags, TABLE_IDS_FLAG)) {
                sponge.absorb_g_single(l_index.table_ids);
            }
            if (Proof.is_field_set(l_index.optional_field_flags, RUNTIME_TABLES_SELECTOR_FLAG)) {
                sponge.absorb_g_single(l_index.runtime_tables_selector);
            }

            if (Proof.is_field_set(l_index.optional_field_flags, XOR_FLAG)) {
                sponge.absorb_g_single(l_index.xor);
            }
            if (Proof.is_field_set(l_index.optional_field_flags, LOOKUP_FLAG)) {
                sponge.absorb_g_single(l_index.lookup);
            }
            if (Proof.is_field_set(l_index.optional_field_flags, RANGE_CHECK_FLAG)) {
                sponge.absorb_g_single(l_index.range_check);
            }
            if (Proof.is_field_set(l_index.optional_field_flags, FFMUL_FLAG)) {
                sponge.absorb_g_single(l_index.ffmul);
            }
        }
        return sponge.digest_base();
    }

    function get_column_commitment(
        Column memory column,
        VerifierIndex storage verifier_index,
        Proof.ProverProof storage proof
    ) internal view returns (BN254.G1Point memory) {
        LookupVerifierIndex memory l_index = verifier_index.lookup_index;

        uint256 inner = column.inner;
        ColumnVariant variant = column.variant;
        if (variant == ColumnVariant.Witness) {
            return proof.commitments.w_comm[inner];
        } else if (variant == ColumnVariant.Coefficient) {
            return verifier_index.coefficients_comm[inner];
        } else if (variant == ColumnVariant.Permutation) {
            return verifier_index.sigma_comm[inner];
        } else if (variant == ColumnVariant.Z) {
            return proof.commitments.z_comm;
        } else if (variant == ColumnVariant.LookupSorted) {
            return proof.commitments.lookup_sorted[inner];
        } else if (variant == ColumnVariant.LookupAggreg) {
            return proof.commitments.lookup_aggreg;
        } else if (variant == ColumnVariant.LookupKindIndex) {
            if (inner == LOOKUP_PATTERN_XOR) {
                if (!Proof.is_field_set(l_index.optional_field_flags, XOR_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.xor;
            }
            if (inner == LOOKUP_PATTERN_LOOKUP) {
                if (!Proof.is_field_set(l_index.optional_field_flags, LOOKUP_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.lookup;
            }
            if (inner == LOOKUP_PATTERN_RANGE_CHECK) {
                if (!Proof.is_field_set(l_index.optional_field_flags, RANGE_CHECK_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.range_check;
            }
            if (inner == LOOKUP_PATTERN_FOREIGN_FIELD_MUL) {
                if (!Proof.is_field_set(l_index.optional_field_flags, FFMUL_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.ffmul;
            } else {
                revert MissingLookupColumnCommitment(inner);
            }
        } else if (variant == ColumnVariant.LookupRuntimeSelector) {
            if (!Proof.is_field_set(l_index.optional_field_flags, RUNTIME_TABLES_SELECTOR_FLAG)) {
                revert MissingCommitment(variant);
            }
            return l_index.runtime_tables_selector;
        } else if (variant == ColumnVariant.LookupRuntimeTable) {
            if (!Proof.is_field_set(proof.commitments.optional_field_flags, LOOKUP_RUNTIME_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return proof.commitments.lookup_runtime;
        } else if (variant == ColumnVariant.Index) {
            if (inner == GATE_TYPE_GENERIC) {
                return verifier_index.generic_comm;
            } else if (inner == GATE_TYPE_COMPLETE_ADD) {
                return verifier_index.complete_add_comm;
            } else if (inner == GATE_TYPE_VAR_BASE_MUL) {
                return verifier_index.mul_comm;
            } else if (inner == GATE_TYPE_ENDO_MUL) {
                return verifier_index.emul_comm;
            } else if (inner == GATE_TYPE_ENDO_MUL_SCALAR) {
                return verifier_index.endomul_scalar_comm;
            } else if (inner == GATE_TYPE_POSEIDON) {
                return verifier_index.psm_comm;
            } else if (inner == GATE_TYPE_RANGE_CHECK_0) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, RANGE_CHECK0_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.range_check0_comm;
            } else if (inner == GATE_TYPE_RANGE_CHECK_1) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, RANGE_CHECK1_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.range_check1_comm;
            } else if (inner == GATE_TYPE_FOREIGN_FIELD_ADD) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, FOREIGN_FIELD_ADD_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.foreign_field_add_comm;
            } else if (inner == GATE_TYPE_FOREIGN_FIELD_MUL) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, FOREIGN_FIELD_MUL_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.foreign_field_mul_comm;
            } else if (inner == GATE_TYPE_XOR_16) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, XOR_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.xor_comm;
            } else if (inner == GATE_TYPE_ROT_64) {
                if (!Proof.is_field_set(verifier_index.optional_field_flags, ROT_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.rot_comm;
            } else {
                revert Proof.MissingIndexColumnEvaluation(inner);
            }
        } else {
            revert MissingCommitment(column.variant);
        }

        // TODO: other variants remain to be implemented.
    }
}
