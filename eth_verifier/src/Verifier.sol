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

import "forge-std/console.sol";

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
    using {register} for Alphas;

    // Column variant constants
    // - GateType
    uint256 internal constant GATE_TYPE_GENERIC = 0;
    uint256 internal constant GATE_TYPE_POSEIDON = 1;
    uint256 internal constant GATE_TYPE_COMPLETE_ADD = 2;
    uint256 internal constant GATE_TYPE_VAR_BASE_MUL = 3;
    uint256 internal constant GATE_TYPE_ENDO_MUL = 4;
    uint256 internal constant GATE_TYPE_ENDO_MUL_SCALAR = 5;
    uint256 internal constant GATE_TYPE_RANGE_CHECK_0 = 6;
    uint256 internal constant GATE_TYPE_RANGE_CHECK_1 = 7;
    uint256 internal constant GATE_TYPE_FOREIGN_FIELD_ADD = 8;
    uint256 internal constant GATE_TYPE_FOREIGN_FIELD_MUL = 9;
    uint256 internal constant GATE_TYPE_XOR_16 = 10;
    uint256 internal constant GATE_TYPE_ROT_64 = 11;
    // - LookupPattern
    uint256 internal constant LOOKUP_PATTERN_XOR = 0;
    uint256 internal constant LOOKUP_PATTERN_LOOKUP = 1;
    uint256 internal constant LOOKUP_PATTERN_RANGE_CHECK = 2;
    uint256 internal constant LOOKUP_PATTERN_FOREIGN_FIELD_MUL = 3;

    error IncorrectPublicInputLength();
    error PolynomialsAreChunked(uint256 chunk_size);

    VerifierIndex verifier_index;
    URS urs;

    ProverProof proof;
    Scalar.FE public_input;

    AggregatedEvaluationProof aggregated_proof;

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
        AggregatedEvaluationProof memory agg_proof = partial_verify();
        return final_verify(agg_proof);
    }

    function partial_verify_and_store() public {
        aggregated_proof = partial_verify();
    }

    // This takes Kimchi's `to_batch()` as reference.
    function partial_verify() public returns (AggregatedEvaluationProof memory) {
        // TODO: 1. CHeck the length of evaluations insde the proof

        // 2. Commit to the negated public input polynomial.
        BN254.G1Point memory public_comm = public_commitment();

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
        if (is_field_set(verifier_index, RANGE_CHECK0_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_RANGE_CHECK_0);
        }
        if (is_field_set(verifier_index, RANGE_CHECK1_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_RANGE_CHECK_1);
        }
        if (is_field_set(verifier_index, FOREIGN_FIELD_ADD_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_FOREIGN_FIELD_ADD);
        }
        if (is_field_set(verifier_index, FOREIGN_FIELD_MUL_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_FOREIGN_FIELD_MUL);
        }
        if (is_field_set(verifier_index, XOR_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_XOR_16);
        }
        if (is_field_set(verifier_index, ROT_COMM_FLAG)) {
            columns[col_index++] = Column(ColumnVariant.Index, GATE_TYPE_ROT_64);
        }
        if (is_field_set(verifier_index, LOOKUP_VERIFIER_INDEX_FLAG)) {
            LookupVerifierIndex memory li = verifier_index.lookup_index;
            for (uint256 i = 0; i < li.lookup_info.max_per_row + 1; i++) {
                columns[col_index++] = Column(ColumnVariant.LookupSorted, i);
            }
            columns[col_index++] = Column(ColumnVariant.LookupAggreg, 0);
        }
        // push all commitments corresponding to each column
        for (uint256 i = 0; i < col_index; i++) {
            PointEvaluations memory eval = get_column_eval(proof.evals, columns[i]);
            evaluations[eval_index++] = Evaluation(get_column_commitment(columns[i]), [eval.zeta, eval.zeta_omega], 0);
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
                Column memory col = Column(ColumnVariant.LookupRuntimeSelector, 0);
                PointEvaluations memory eval = get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(get_column_commitment(col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, XOR_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_XOR);
                PointEvaluations memory eval = get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(get_column_commitment(col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, LOOKUP_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_LOOKUP);
                PointEvaluations memory eval = get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(get_column_commitment(col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, RANGE_CHECK_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_RANGE_CHECK);
                PointEvaluations memory eval = get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(get_column_commitment(col), [eval.zeta, eval.zeta_omega], 0);
            }
            if (is_field_set(li, FFMUL_FLAG)) {
                Column memory col = Column(ColumnVariant.LookupKindIndex, LOOKUP_PATTERN_FOREIGN_FIELD_MUL);
                PointEvaluations memory eval = get_column_eval(proof.evals, col);
                evaluations[eval_index++] = Evaluation(get_column_commitment(col), [eval.zeta, eval.zeta_omega], 0);
            }
        }

        Scalar.FE[2] memory evaluation_points = [oracles.zeta, oracles.zeta.mul(verifier_index.domain_gen)];

        return AggregatedEvaluationProof(evaluations, evaluation_points, oracles.v, proof.opening);
    }

    function public_commitment() public view returns (BN254.G1Point memory public_comm) {
        if (verifier_index.domain_size < verifier_index.max_poly_size) {
            revert PolynomialsAreChunked(verifier_index.domain_size / verifier_index.max_poly_size);
        }

        if (verifier_index.public_len != 1) {
            revert IncorrectPublicInputLength();
        }
        BN254.G1Point memory lagrange_base = BN254.G1Point(
            0x280c10e2f52fb4ab3ba21204b30df5b69560978e0911a5c673ad0558070f17c1,
            0x287897da7c8db33cd988a1328770890b2754155612290448267f9ca4c549cb39
        );

        public_comm = urs.h.add(lagrange_base.scale_scalar(public_input).neg());
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

    function get_column_eval(ProofEvaluations memory evals, Column memory col)
        internal
        pure
        returns (PointEvaluations memory)
    {
        ColumnVariant variant = col.variant;
        uint256 inner = col.inner;
        if (variant == ColumnVariant.Witness) {
            return evals.w[inner];
        } else if (variant == ColumnVariant.Z) {
            return evals.z;
        } else if (variant == ColumnVariant.LookupSorted) {
            return evals.lookup_sorted[inner];
        } else if (variant == ColumnVariant.LookupAggreg) {
            return evals.lookup_aggregation;
        } else if (variant == ColumnVariant.LookupTable) {
            return evals.lookup_table;
        } else if (variant == ColumnVariant.LookupKindIndex) {
            if (inner == LOOKUP_PATTERN_XOR) return evals.xor_lookup_selector;
            else if (inner == LOOKUP_PATTERN_LOOKUP) return evals.lookup_gate_lookup_selector;
            else if (inner == LOOKUP_PATTERN_RANGE_CHECK) return evals.range_check_lookup_selector;
            else if (inner == LOOKUP_PATTERN_FOREIGN_FIELD_MUL) return evals.foreign_field_mul_lookup_selector;
            else revert MissingLookupColumnEvaluation(inner);
        } else if (variant == ColumnVariant.LookupRuntimeSelector) {
            return evals.runtime_lookup_table_selector;
        } else if (variant == ColumnVariant.Index) {
            if (inner == GATE_TYPE_GENERIC) return evals.generic_selector;
            else if (inner == GATE_TYPE_POSEIDON) return evals.poseidon_selector;
            else if (inner == GATE_TYPE_COMPLETE_ADD) return evals.complete_add_selector;
            else if (inner == GATE_TYPE_VAR_BASE_MUL) return evals.mul_selector;
            else if (inner == GATE_TYPE_ENDO_MUL) return evals.emul_selector;
            else if (inner == GATE_TYPE_ENDO_MUL_SCALAR) return evals.endomul_scalar_selector;
            else if (inner == GATE_TYPE_RANGE_CHECK_0) return evals.range_check0_selector;
            else if (inner == GATE_TYPE_RANGE_CHECK_1) return evals.range_check1_selector;
            else if (inner == GATE_TYPE_FOREIGN_FIELD_ADD) return evals.foreign_field_add_selector;
            else if (inner == GATE_TYPE_FOREIGN_FIELD_MUL) return evals.foreign_field_mul_selector;
            else if (inner == GATE_TYPE_XOR_16) return evals.xor_selector;
            else if (inner == GATE_TYPE_ROT_64) return evals.rot_selector;
            else revert MissingIndexColumnEvaluation(inner);
        } else if (variant == ColumnVariant.Coefficient) {
            return evals.coefficients[inner];
        } else if (variant == ColumnVariant.Permutation) {
            return evals.s[inner];
        } else {
            revert MissingColumnEvaluation(variant);
        }
    }

    function get_column_commitment(Column memory column) internal view returns (BN254.G1Point memory) {
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
                if (!is_field_set(l_index, XOR_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.xor;
            }
            if (inner == LOOKUP_PATTERN_LOOKUP) {
                if (!is_field_set(l_index, LOOKUP_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.lookup;
            }
            if (inner == LOOKUP_PATTERN_RANGE_CHECK) {
                if (!is_field_set(l_index, RANGE_CHECK_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.range_check;
            }
            if (inner == LOOKUP_PATTERN_FOREIGN_FIELD_MUL) {
                if (!is_field_set(l_index, FFMUL_FLAG)) {
                    revert MissingLookupColumnCommitment(inner);
                }
                return l_index.ffmul;
            } else {
                revert MissingLookupColumnCommitment(inner);
            }
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
                if (!is_field_set(verifier_index, RANGE_CHECK0_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.range_check0_comm;
            } else if (inner == GATE_TYPE_RANGE_CHECK_1) {
                if (!is_field_set(verifier_index, RANGE_CHECK1_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.range_check1_comm;
            } else if (inner == GATE_TYPE_FOREIGN_FIELD_ADD) {
                if (!is_field_set(verifier_index, FOREIGN_FIELD_ADD_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.foreign_field_add_comm;
            } else if (inner == GATE_TYPE_FOREIGN_FIELD_MUL) {
                if (!is_field_set(verifier_index, FOREIGN_FIELD_MUL_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.foreign_field_mul_comm;
            } else if (inner == GATE_TYPE_XOR_16) {
                if (!is_field_set(verifier_index, XOR_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.xor_comm;
            } else if (inner == GATE_TYPE_ROT_64) {
                if (!is_field_set(verifier_index, ROT_COMM_FLAG)) {
                    revert MissingCommitment(variant);
                }
                return verifier_index.rot_comm;
            } else {
                revert MissingIndexColumnEvaluation(inner);
            }
        } else {
            revert MissingCommitment(column.variant);
        }

        // TODO: other variants remain to be implemented.
    }

    function final_verify_stored() public view returns (bool) {
        return final_verify(aggregated_proof);
    }

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
}
