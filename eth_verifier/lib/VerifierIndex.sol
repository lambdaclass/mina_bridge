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

using {
    KeccakSponge.reinit,
    KeccakSponge.absorb_base,
    KeccakSponge.absorb_scalar,
    KeccakSponge.absorb_scalar_multiple,
    KeccakSponge.absorb_commitment,
    KeccakSponge.absorb_evaluations,
    KeccakSponge.absorb_g,
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

struct LookupSelectors {
    PolyComm xor; // INFO: optional
    bool is_xor_set;

    PolyComm lookup; // INFO: optional
    bool is_lookup_set;

    PolyComm range_check; // INFO: optional
    bool is_range_check_set;

    PolyComm ffmul; // INFO: optional
    bool is_ffmul_set;
}

struct LookupInfo {
    uint256 max_per_row;
    uint256 max_joint_size;
    // TODO: lookup features
}

function verifier_digest(VerifierIndex storage index) returns (Base.FE) {
    index.sponge.reinit();

    for (uint i = 0; i < index.sigma_comm.length; i++) {
        index.sponge.absorb_g(index.sigma_comm[i].unshifted);
    }
    for (uint i = 0; i < index.coefficients_comm.length; i++) {
        index.sponge.absorb_g(index.coefficients_comm[i].unshifted);
    }
    index.sponge.absorb_g(index.generic_comm.unshifted);
    index.sponge.absorb_g(index.psm_comm.unshifted);
    index.sponge.absorb_g(index.complete_add_comm.unshifted);
    index.sponge.absorb_g(index.mul_comm.unshifted);
    index.sponge.absorb_g(index.emul_comm.unshifted);
    index.sponge.absorb_g(index.endomul_scalar_comm.unshifted);

    // optional

    if (index.is_range_check0_comm_set) {
        index.sponge.absorb_g(index.range_check0_comm.unshifted);
    }

    if (index.is_range_check1_comm_set) {
        index.sponge.absorb_g(index.range_check1_comm.unshifted);
    }

    if (index.is_foreign_field_mul_comm_set) {
        index.sponge.absorb_g(index.foreign_field_mul_comm.unshifted);
    }

    if (index.is_foreign_field_add_comm_set) {
        index.sponge.absorb_g(index.foreign_field_add_comm.unshifted);
    }

    if (index.is_xor_comm_set) {
        index.sponge.absorb_g(index.xor_comm.unshifted);
    }

    if (index.is_rot_comm_set) {
        index.sponge.absorb_g(index.rot_comm.unshifted);
    }

    if (index.is_lookup_index_set) {
        LookupVerifierIndex storage l_index = index.lookup_index;
        for (uint i = 0; i < l_index.lookup_table.length; i++) {
            index.sponge.absorb_g(l_index.lookup_table[i].unshifted);
        }
        if (l_index.is_table_ids_set) {
            index.sponge.absorb_g(l_index.table_ids.unshifted);
        }
        if (l_index.is_runtime_tables_selector_set) {
            index.sponge.absorb_g(l_index.runtime_tables_selector.unshifted);
        }

        LookupSelectors storage l_selectors = l_index.lookup_selectors;
        if (l_selectors.is_xor_set) {
            index.sponge.absorb_g(l_selectors.xor.unshifted);
        }
        if (l_selectors.is_lookup_set) {
            index.sponge.absorb_g(l_selectors.lookup.unshifted);
        }
        if (l_selectors.is_range_check_set) {
            index.sponge.absorb_g(l_selectors.range_check.unshifted);
        }
        if (l_selectors.is_ffmul_set) {
            index.sponge.absorb_g(l_selectors.ffmul.unshifted);
        }
    }

    return index.sponge.digest_base();
}

function get_column_commitment(VerifierIndex storage verifier_index, ProverProof storage proof, Column memory column)
    view
    returns (PolyComm memory)
{
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
        return proof.commitments.lookup.sorted[i];
    } else if (variant == ColumnVariant.LookupAggreg) {
        return proof.commitments.lookup.aggreg;
    } else if (variant == ColumnVariant.LookupKindIndex) {
        LookupPattern pattern = abi.decode(data, (LookupPattern));
        if (pattern == LookupPattern.Xor) {
            if (!verifier_index.lookup_index.lookup_selectors.is_xor_set) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return verifier_index.lookup_index.lookup_selectors.xor;
        }
        if (pattern == LookupPattern.Lookup) {
            if (!verifier_index.lookup_index.lookup_selectors.is_lookup_set) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return verifier_index.lookup_index.lookup_selectors.lookup;
        }
        if (pattern == LookupPattern.RangeCheck) {
            if (!verifier_index.lookup_index.lookup_selectors.is_range_check_set) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return verifier_index.lookup_index.lookup_selectors.range_check;
        }
        if (pattern == LookupPattern.ForeignFieldMul) {
            if (!verifier_index.lookup_index.lookup_selectors.is_ffmul_set) {
                revert MissingLookupColumnCommitment(pattern);
            }
            return verifier_index.lookup_index.lookup_selectors.ffmul;
        }
        else { revert MissingLookupColumnCommitment(pattern); }
    } else if (variant == ColumnVariant.LookupRuntimeSelector) {
        if (!verifier_index.lookup_index.is_runtime_tables_selector_set) {
            revert MissingCommitment(variant);
        }
        return verifier_index.lookup_index.runtime_tables_selector;
    } else if (variant == ColumnVariant.LookupRuntimeTable) {
        if (!proof.commitments.is_lookup_set || !proof.commitments.lookup.is_runtime_set) {
            revert MissingCommitment(variant);
        }
        return proof.commitments.lookup.runtime;
    } else if (variant == ColumnVariant.Index) {
        GateType gate = abi.decode(data, (GateType));
        if (gate == GateType.Generic) { return verifier_index.generic_comm; }
        else if (gate == GateType.CompleteAdd) { return verifier_index.complete_add_comm; }
        else if (gate == GateType.VarBaseMul) { return verifier_index.mul_comm; }
        else if (gate == GateType.EndoMul) { return verifier_index.emul_comm; }
        else if (gate == GateType.EndoMulScalar) { return verifier_index.endomul_scalar_comm; }
        else if (gate == GateType.Poseidon) { return verifier_index.psm_comm; }
        else if (gate == GateType.RangeCheck0) {
            if (!verifier_index.is_range_check0_comm_set) {
                revert MissingCommitment(variant);
            }
            return verifier_index.range_check0_comm;
        }
        else if (gate == GateType.RangeCheck1) {
            if (!verifier_index.is_range_check1_comm_set) {
                revert MissingCommitment(variant);
            }
            return verifier_index.range_check1_comm;
        }
        else if (gate == GateType.ForeignFieldAdd) {
            if (!verifier_index.is_foreign_field_add_comm_set) {
                revert MissingCommitment(variant);
            }
            return verifier_index.foreign_field_add_comm;
        }
        else if (gate == GateType.ForeignFieldMul) {
            if (!verifier_index.is_foreign_field_mul_comm_set) {
                revert MissingCommitment(variant);
            }
            return verifier_index.foreign_field_mul_comm;
        }
        else if (gate == GateType.Xor16) {
            if (!verifier_index.is_xor_comm_set) {
                revert MissingCommitment(variant);
            }
            return verifier_index.xor_comm;
        }
        else if (gate == GateType.Rot64) {
            if (!verifier_index.is_rot_comm_set) {
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
