// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./bn254/BN254.sol";
import {URS} from "./Commitment.sol";
import "./bn254/Fields.sol";
import "./Alphas.sol";
import "./Evaluations.sol";
import "./expr/Expr.sol";
import "./Proof.sol";
import "./sponge/Sponge.sol";
import "./Constants.sol";

using {
    KeccakSponge.reinit,
    KeccakSponge.absorb_base,
    KeccakSponge.absorb_scalar,
    KeccakSponge.absorb_scalar_multiple,
    KeccakSponge.absorb_commitment,
    KeccakSponge.absorb_evaluations,
    KeccakSponge.absorb_g,
    KeccakSponge.absorb_g_single,
    KeccakSponge.challenge_base,
    KeccakSponge.challenge_scalar,
    KeccakSponge.digest_base,
    KeccakSponge.digest_scalar
} for Sponge;

error MissingCommitment(ColumnVariant variant);
error MissingLookupColumnCommitment(LookupPattern pattern);
error MissingIndexColumnCommitment(GateType gate);

struct VerifierIndex {
    // this is used for generating the index's digest
    Sponge sponge;

    // number of public inputs
    uint256 public_len;
    // maximal size of polynomial section
    uint256 max_poly_size;
    // the number of randomized rows to achieve zero knowledge
    uint64 zk_rows;
    // domain
    uint64 domain_size;
    Scalar.FE domain_gen;
    /// The mapping between powers of alpha and constraints
    Alphas powers_of_alpha;
    // wire shift coordinates
    Scalar.FE[7] shift; // TODO: use Consants.PERMUTS
    /// domain offset for zero-knowledge
    Scalar.FE w;
    Linearization linearization;
    // polynomial commitments

    // permutation commitment array
    PolyComm[7] sigma_comm; // TODO: use Constants.PERMUTS
    // coefficient commitment array
    PolyComm[15] coefficients_comm; // TODO: use Constants.COLUMNS
    // TODO: doc
    PolyComm generic_comm;

    // poseidon constraint selector polynomial commitment
    PolyComm psm_comm;

    // ECC arithmetic polynomial commitments

    // EC addition selector polynomial commitment
    PolyComm complete_add_comm;
    // EC variable base scalar multiplication selector polynomial commitment
    PolyComm mul_comm;
    // endoscalar multiplication selector polynomial commitment
    PolyComm emul_comm;
    // endoscalar multiplication scalar computation selector polynomial commitment
    PolyComm endomul_scalar_comm;

    // RangeCheck0 polynomial commitments
    PolyComm range_check0_comm; // INFO: optional
    bool is_range_check0_comm_set;

    // RangeCheck1 polynomial commitments
    PolyComm range_check1_comm; // INFO: optional
    bool is_range_check1_comm_set;

    // Foreign field addition gates polynomial commitments
    PolyComm foreign_field_add_comm; // INFO: optional
    bool is_foreign_field_add_comm_set;

    // Foreign field multiplication gates polynomial commitments
    PolyComm foreign_field_mul_comm; // INFO: optional
    bool is_foreign_field_mul_comm_set;

    // Xor commitments
    PolyComm xor_comm; // INFO: optional
    bool is_xor_comm_set;

    // Rot commitments
    PolyComm rot_comm; // INFO: optional
    bool is_rot_comm_set;

    LookupVerifierIndex lookup_index; // INFO: optional
    bool is_lookup_index_set;

    Scalar.FE endo;
}

struct NewVerifierIndex {
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

    NewLookupVerifierIndex lookup_index; // INFO: optional

    // this is used for generating the index's digest
    Sponge sponge;

    Linearization linearization;

    /// The mapping between powers of alpha and constraints
    Alphas powers_of_alpha;
}

struct LookupVerifierIndex {
    PolyComm[] lookup_table;
    LookupSelectors lookup_selectors;
    LookupInfo lookup_info;

    // table IDs for the lookup values.
    // this may be not set if all lookups originate from table 0.
    PolyComm table_ids; // INFO: optional
    bool is_table_ids_set;

    // an optional selector polynomial for runtime tables
    PolyComm runtime_tables_selector; // INFO: optional
    bool is_runtime_tables_selector_set;
}

struct NewLookupVerifierIndex {
    // each bit represents the presence (1) or absence (0) of an
    // optional field.
    uint256 optional_field_flags;

    BN254.G1Point lookup_table;

    NewLookupInfo lookup_info;

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
    // each bit represents the presence (1) or absence (0) of an
    // optional field.
    uint256 optional_field_flags;

    PolyComm xor; // INFO: optional
    bool is_xor_set;

    PolyComm lookup; // INFO: optional
    bool is_lookup_set;

    PolyComm range_check; // INFO: optional
    bool is_range_check_set;

    PolyComm ffmul; // INFO: optional
    bool is_ffmul_set;
}

struct NewLookupSelectors {

    BN254.G1Point xor; // INFO: optional

    BN254.G1Point lookup; // INFO: optional

    BN254.G1Point range_check; // INFO: optional

    BN254.G1Point ffmul; // INFO: optional
}

struct LookupInfo {
    uint256 max_per_row;
    uint256 max_joint_size;
    // TODO: lookup features
}

struct NewLookupInfo {
    uint256 max_per_row;
    uint256 max_joint_size;
    // TODO: lookup features
}

function verifier_digest(NewVerifierIndex storage index) returns (Base.FE) {
    index.sponge.reinit();

    for (uint i = 0; i < index.sigma_comm.length; i++) {
        index.sponge.absorb_g_single(index.sigma_comm[i]);
    }
    for (uint i = 0; i < index.coefficients_comm.length; i++) {
        index.sponge.absorb_g_single(index.coefficients_comm[i]);
    }
    index.sponge.absorb_g_single(index.generic_comm);
    index.sponge.absorb_g_single(index.psm_comm);
    index.sponge.absorb_g_single(index.complete_add_comm);
    index.sponge.absorb_g_single(index.mul_comm);
    index.sponge.absorb_g_single(index.emul_comm);
    index.sponge.absorb_g_single(index.endomul_scalar_comm);

    // optional

    if (is_field_set(index, RANGE_CHECK0_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.range_check0_comm);
    }

    if (is_field_set(index, RANGE_CHECK1_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.range_check1_comm);
    }

    if (is_field_set(index, FOREIGN_FIELD_MUL_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.foreign_field_mul_comm);
    }

    if (is_field_set(index, FOREIGN_FIELD_ADD_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.foreign_field_add_comm);
    }

    if (is_field_set(index, XOR_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.xor_comm);
    }

    if (is_field_set(index, ROT_COMM_FLAG)) {
        index.sponge.absorb_g_single(index.rot_comm);
    }

    if (is_field_set(index, LOOKUP_VERIFIER_INDEX_FLAG)) {
        NewLookupVerifierIndex storage l_index = index.lookup_index;
        index.sponge.absorb_g_single(l_index.lookup_table);
        if (is_field_set(l_index, TABLE_IDS_FLAG)) {
            index.sponge.absorb_g_single(l_index.table_ids);
        }
        if (is_field_set(l_index, RUNTIME_TABLES_SELECTOR_FLAG)) {
            index.sponge.absorb_g_single(l_index.runtime_tables_selector);
        }

        if (is_field_set(l_index, XOR_FLAG)) {
            index.sponge.absorb_g_single(l_index.xor);
        }
        if (is_field_set(l_index, LOOKUP_FLAG)) {
            index.sponge.absorb_g_single(l_index.lookup);
        }
        if (is_field_set(l_index, RANGE_CHECK_FLAG)) {
            index.sponge.absorb_g_single(l_index.range_check);
        }
        if (is_field_set(l_index, FFMUL_FLAG)) {
            index.sponge.absorb_g_single(l_index.ffmul);
        }
    }

    return index.sponge.digest_base();
}

function get_column_commitment(
    NewVerifierIndex storage verifier_index,
    ProverProof storage proof,
    Column memory column
)
    view
    returns (BN254.G1Point memory)
{
    NewLookupVerifierIndex memory l_index = verifier_index.lookup_index;

    bytes memory data = column.data;
    ColumnVariant variant = column.variant;
    if (variant == ColumnVariant.Witness) {
        uint256 i = abi.decode(data, (uint256));
        return proof.commitments.w_comm[i];
    } else if (variant == ColumnVariant.Coefficient) {
        uint256 i = abi.decode(data, (uint256));
        return verifier_index.coefficients_comm[i];
    } else if (variant == ColumnVariant.Permutation) {
        uint256 i = abi.decode(data, (uint256));
        return verifier_index.sigma_comm[i];
    } else if (variant == ColumnVariant.Z) {
        return proof.commitments.z_comm;
    } else if (variant == ColumnVariant.LookupSorted) {
        uint256 i = abi.decode(data, (uint256));
        return proof.commitments.lookup_sorted[i];
    } else if (variant == ColumnVariant.LookupAggreg) {
        return proof.commitments.lookup_aggreg;
    } else if (variant == ColumnVariant.LookupKindIndex) {
        LookupPattern pattern = abi.decode(data, (LookupPattern));
        if (pattern == LookupPattern.Xor) {
            if (!is_field_set(l_index, XOR_FLAG)) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return l_index.xor;
        }
        if (pattern == LookupPattern.Lookup) {
            if (!is_field_set(l_index, LOOKUP_FLAG)) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return l_index.lookup;
        }
        if (pattern == LookupPattern.RangeCheck) {
            if (!is_field_set(l_index, RANGE_CHECK_FLAG)) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return l_index.range_check;
        }
        if (pattern == LookupPattern.ForeignFieldMul) {
            if (!is_field_set(l_index, FFMUL_FLAG)) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return l_index.ffmul;
        }
        else { revert MissingLookupColumnCommitment(pattern); }
    } else if (variant == ColumnVariant.LookupRuntimeSelector) {
        if (!is_field_set(l_index, RUNTIME_TABLES_SELECTOR_FLAG)) {
            revert MissingCommitment(variant);
        }
        return l_index.runtime_tables_selector;
    } else if (variant == ColumnVariant.LookupRuntimeTable) {
        if (!is_field_set(proof.commitments, LOOKUP_RUNTIME_COMM_FLAG)) {
            revert MissingCommitment(variant);
        }
        return proof.commitments.lookup_runtime;
    } else if (variant == ColumnVariant.Index) {
        GateType gate = abi.decode(data, (GateType));
        if (gate == GateType.Generic) { return verifier_index.generic_comm; }
        else if (gate == GateType.CompleteAdd) { return verifier_index.complete_add_comm; }
        else if (gate == GateType.VarBaseMul) { return verifier_index.mul_comm; }
        else if (gate == GateType.EndoMul) { return verifier_index.emul_comm; }
        else if (gate == GateType.EndoMulScalar) { return verifier_index.endomul_scalar_comm; }
        else if (gate == GateType.Poseidon) { return verifier_index.psm_comm; }
        else if (gate == GateType.RangeCheck0) {
            if (!is_field_set(verifier_index, RANGE_CHECK0_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.range_check0_comm;
        }
        else if (gate == GateType.RangeCheck1) {
            if (!is_field_set(verifier_index, RANGE_CHECK1_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.range_check1_comm;
        }
        else if (gate == GateType.ForeignFieldAdd) {
            if (!is_field_set(verifier_index, FOREIGN_FIELD_ADD_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.foreign_field_add_comm;
        }
        else if (gate == GateType.ForeignFieldMul) {
            if (!is_field_set(verifier_index, FOREIGN_FIELD_MUL_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.foreign_field_mul_comm;
        }
        else if (gate == GateType.Xor16) {
            if (!is_field_set(verifier_index, XOR_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.xor_comm;
        }
        else if (gate == GateType.Rot64) {
            if (!is_field_set(verifier_index, ROT_COMM_FLAG)) {
                revert MissingCommitment(variant);
            }
            return verifier_index.rot_comm;
        }
        else { revert MissingIndexColumnEvaluation(gate); }
    } else {
        revert MissingCommitment(column.variant);
    }

    // TODO: other variants remain to be implemented.
}
