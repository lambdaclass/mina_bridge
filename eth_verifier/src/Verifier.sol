// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Commitment.sol";
import "../lib/Oracles.sol";
import "../lib/Proof.sol";
import "../lib/State.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Constants.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Alphas.sol";
import "../lib/Evaluations.sol";
import "../lib/expr/Expr.sol";
import "../lib/expr/PolishToken.sol";
import "../lib/expr/ExprConstants.sol";

using {BN254.neg, BN254.scalarMul} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {get_alphas} for Alphas;
using {it_next} for AlphasIterator;
using {Polynomial.evaluate} for Polynomial.Dense;
using {sub_polycomms, scale_polycomm} for PolyComm;
using {get_column_eval} for ProofEvaluationsArray;

contract KimchiVerifier {
    using {register} for Alphas;
    using {combine_evals} for ProofEvaluationsArray;
    using {chunk_commitment} for PolyComm;

    VerifierIndex verifier_index;
    ProverProof proof;
    PairingURS urs;

    Sponge base_sponge;
    Sponge scalar_sponge;

    State internal state;
    bool state_available;

    function setup(bytes memory urs_serialized) public {
        MsgPk.deser_pairing_urs(MsgPk.new_stream(urs_serialized), urs);

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
        bytes calldata linearization_serialized_rlp
    )
        public
    {
        MsgPk.deser_verifier_index(MsgPk.new_stream(verifier_index_serialized), verifier_index);
        MsgPk.deser_prover_proof(MsgPk.new_stream(prover_proof_serialized), proof);
        verifier_index.linearization = abi.decode(linearization_serialized_rlp, (Linearization));
    }

    function verify_with_index(
        bytes calldata verifier_index_serialized,
        bytes calldata prover_proof_serialized,
        bytes calldata linearization_serialized_rlp,
        bytes32 numerator_serialized
    ) public returns (bool) {
        deserialize_proof(verifier_index_serialized, prover_proof_serialized, linearization_serialized_rlp);
        // The numerator was "manually" serialized so we can't use deser_g1point();
        BN254.G1Point memory numerator = BN254.g1Deserialize(numerator_serialized);
        // "numerator" is a fake commitment that should be calculated after running
        // all the partial verifier.

        //calculate_lagrange_bases(
        //    verifier_index.urs.g,
        //    verifier_index.urs.h,
        //    verifier_index.domain_size,
        //    verifier_index.urs.lagrange_bases_unshifted
        //);

        AggregatedEvaluationProof memory agg_proof = partial_verify(new Scalar.FE[](0));

        return final_verify(agg_proof, urs.verifier_urs, numerator);
    }

    /// @notice this is currently deprecated but remains as to not break
    /// @notice the demo.
    function verify_state(bytes calldata state_serialized, bytes calldata proof_serialized) public returns (bool) {
        // 1. Deserialize proof and setup

        // For now, proof consists in the concatenation of the bytes that
        // represent the numerator, quotient and divisor polynomial
        // commitments (G1 and G2 points).

        // BEWARE: quotient must be negated.

        (BN254.G1Point memory numerator, BN254.G1Point memory quotient, BN254.G2Point memory divisor) =
            MsgPk.deserializeFinalCommitments(proof_serialized);

        bool success = BN254.pairingProd2(numerator, BN254.P2(), quotient, divisor);

        // 3. If success, deserialize and store state
        if (success) {
            store_state(state_serialized);
            state_available = true;
        }

        return success;
    }

    error IncorrectPublicInputLength();

    // This takes Kimchi's `to_batch()` as reference.
    function partial_verify(Scalar.FE[] memory public_inputs) public returns (AggregatedEvaluationProof memory ){
        // TODO: 1. CHeck the length of evaluations insde the proof

        // 2. Commit to the negated public input polynomial.

        uint256 chunk_size = verifier_index.domain_size < verifier_index.max_poly_size
            ? 1
            : verifier_index.domain_size / verifier_index.max_poly_size;

        if (public_inputs.length != verifier_index.public_len) {
            revert IncorrectPublicInputLength();
        }
        PolyCommFlat memory lgr_comm_flat = urs.lagrange_bases_unshifted[verifier_index.domain_size];
        PolyComm[] memory comm = new PolyComm[](verifier_index.public_len);
        PolyComm[] memory lgr_comm = poly_comm_unflat(lgr_comm_flat);
        // INFO: can use unchecked on for loops to save gas
        for (uint256 i = 0; i < verifier_index.public_len; i++) {
            comm[i] = lgr_comm[i];
        }
        PolyComm memory public_comm;
        if (public_inputs.length == 0) {
            BN254.G1Point[] memory blindings = new BN254.G1Point[](chunk_size);
            for (uint256 i = 0; i < chunk_size; i++) {
                blindings[i] = urs.full_urs.h;
            }
            // TODO: shifted is fixed to infinity
            BN254.G1Point memory shifted = BN254.point_at_inf();
            public_comm = PolyComm(blindings, shifted);
        } else {
            Scalar.FE[] memory elm = new Scalar.FE[](public_inputs.length);
            for (uint256 i = 0; i < elm.length; i++) {
                elm[i] = public_inputs[i].neg();
            }
            PolyComm memory public_comm_tmp = polycomm_msm(comm, elm);
            Scalar.FE[] memory blinders = new Scalar.FE[](public_comm_tmp.unshifted.length);
            for (uint256 i = 0; i < public_comm_tmp.unshifted.length; i++) {
                blinders[i] = Scalar.FE.wrap(1);
            }
            public_comm = mask_custom(urs.full_urs, public_comm_tmp, blinders).commitment;
        }

        // 3. Execute fiat-shamir with a Keccak sponge

        Oracles.Result memory oracles_res = Oracles.fiat_shamir(
            proof,
            verifier_index,
            public_comm,
            public_inputs,
            true,
            base_sponge,
            scalar_sponge
        );
        Oracles.RandomOracles memory oracles = oracles_res.oracles;

        // 4. Combine the chunked polynomials' evaluations

        ProofEvaluations memory evals = proof.evals.combine_evals(oracles_res.powers_of_eval_points_for_chunks);

        // 5. Compute the commitment to the linearized polynomial $f$.
        Scalar.FE permutation_vanishing_polynomial = Polynomial.eval_vanishes_on_last_n_rows(
            verifier_index.domain_gen, verifier_index.domain_size, verifier_index.zk_rows, oracles.zeta);

        AlphasIterator memory alphas =
            verifier_index.powers_of_alpha.get_alphas(ArgumentType.Permutation, PERMUTATION_CONSTRAINTS);

        Linearization memory linear = verifier_index.linearization;

        PolyComm[] memory commitments = new PolyComm[](linear.index_terms.length + 1);
        commitments[0] = verifier_index.sigma_comm[PERMUTS - 1];
        Scalar.FE[] memory scalars = new Scalar.FE[](linear.index_terms.length + 1);
        scalars[0] = perm_scalars(
            evals,
            oracles.beta,
            oracles.gamma,
            alphas,
            permutation_vanishing_polynomial
        );

        ExprConstants memory constants = ExprConstants(
            oracles.alpha,
            oracles.beta,
            oracles.gamma,
            oracles.joint_combiner_field,
            verifier_index.endo,
            verifier_index.zk_rows
        );

        for (uint256 i = 0; i < linear.index_terms.length; i++) {
            Column memory col = linear.index_terms[i].col;
            PolishToken[] memory tokens = linear.index_terms[i].coeff;

            Scalar.FE scalar = evaluate(
                tokens,
                verifier_index.domain_gen,
                verifier_index.domain_size,
                oracles.zeta,
                evals,
                constants
            );

            scalars[i + 1] = scalar;
            commitments[i + 1] = get_column_commitment(verifier_index, proof, col);
        }

        PolyComm memory f_comm = polycomm_msm(commitments, scalars);

        // 6. Compute the chunked commitment of ft
        Scalar.FE zeta_to_srs_len = oracles.zeta.pow(verifier_index.max_poly_size);
        PolyComm memory chunked_f_comm = f_comm.chunk_commitment(zeta_to_srs_len);
        PolyComm memory chunked_t_comm = proof.commitments.t_comm.chunk_commitment(zeta_to_srs_len);
        PolyComm memory ft_comm = chunked_f_comm
            .sub_polycomms(
                chunked_t_comm.scale_polycomm(oracles_res.zeta1.sub(Scalar.one()))
            );

        // 7. List the polynomial commitments, and their associated evaluations,
        // that are associated to the aggregated evaluation proof in the proof:

        uint256 evaluations_len = 55; // INFO: hard-coded for the test proof
        Evaluation[] memory evaluations = new Evaluation[](evaluations_len);

        uint256 eval_index = 0;

        // public input commitment
        evaluations[eval_index++] = Evaluation(
            public_comm,
            oracles_res.public_evals,
            0
        );

        // ft commitment
        Scalar.FE[] memory ft_eval0 = new Scalar.FE[](1);
        Scalar.FE[] memory ft_eval1 = new Scalar.FE[](1);
        ft_eval0[0] = oracles_res.ft_eval0;
        ft_eval1[0] = proof.ft_eval1;
        evaluations[eval_index++] = Evaluation(
            ft_comm,
            [ft_eval0, ft_eval1],
            0
        );
        uint256 columns_len = 51; // INFO: hard-coded for the test proof
        Column[] memory columns = new Column[](columns_len);
        columns[0] = Column(ColumnVariant.Z, new bytes(0));
        columns[1] = Column(ColumnVariant.Index, abi.encode(GateType.Generic));
        columns[2] = Column(ColumnVariant.Index, abi.encode(GateType.Poseidon));
        columns[3] = Column(ColumnVariant.Index, abi.encode(GateType.CompleteAdd));
        columns[4] = Column(ColumnVariant.Index, abi.encode(GateType.VarBaseMul));
        columns[5] = Column(ColumnVariant.Index, abi.encode(GateType.EndoMul));
        columns[6] = Column(ColumnVariant.Index, abi.encode(GateType.EndoMulScalar));
        uint col_index = 7;
        for (uint i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Witness, abi.encode(i));
        }
        for (uint i = 0; i < COLUMNS; i++) {
            columns[col_index++] = Column(ColumnVariant.Coefficient, abi.encode(i));
        }
        for (uint i = 0; i < PERMUTS - 1; i++) {
            columns[col_index++] = Column(ColumnVariant.Permutation, abi.encode(i));
        }
        if (verifier_index.is_range_check0_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck0));
        }
        if (verifier_index.is_range_check1_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck1));
        }
        if (verifier_index.is_foreign_field_add_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldAdd));
        }
        if (verifier_index.is_foreign_field_mul_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldMul));
        }
        if (verifier_index.is_xor_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.Xor16));
        }
        if (verifier_index.is_rot_comm_set) {
            columns[col_index++] = Column(ColumnVariant.Index, abi.encode(GateType.Rot64));
        }
        if (verifier_index.is_lookup_index_set) {
            LookupVerifierIndex memory li = verifier_index.lookup_index;
            for (uint i = 0; i < li.lookup_info.max_per_row + 1; i++) {
                columns[col_index++] = Column(ColumnVariant.LookupSorted, abi.encode(i));
            }
            columns[col_index++] = Column(ColumnVariant.LookupAggreg, new bytes(0));
        }
        // push all commitments corresponding to each column
        for (uint i = 0; i < col_index; i++) {
            PointEvaluationsArray memory eval = get_column_eval(proof.evals, columns[i]);
            evaluations[eval_index++] = Evaluation(
                get_column_commitment(verifier_index, proof, columns[i]),
                [eval.zeta, eval.zeta_omega],
                0
            );
        }

        if (verifier_index.is_lookup_index_set) {
            LookupVerifierIndex memory li = verifier_index.lookup_index;
            if (!proof.commitments.is_lookup_set) {
                revert("missing lookup commitments"); // TODO: error
            }
            LookupCommitments memory lookup_comms = proof.commitments.lookup;
            PointEvaluationsArray memory lookup_evals = proof.evals.lookup_table;
            if (!proof.evals.is_lookup_table_set) {
                revert("missing lookup table eval");
            }
            PointEvaluationsArray memory lookup_table = proof.evals.lookup_table;

            Scalar.FE joint_combiner = oracles.joint_combiner.chal;
            Scalar.FE table_id_combiner = joint_combiner.pow(li.lookup_info.max_joint_size);

            PolyComm memory table_comm = combine_table(
                li.lookup_table,
                joint_combiner,
                table_id_combiner,
                li.is_table_ids_set,
                li.table_ids,
                lookup_comms.is_runtime_set,
                lookup_comms.runtime
            );

            evaluations[eval_index++] = Evaluation(
                table_comm,
                [lookup_table.zeta, lookup_table.zeta_omega],
                0
            );

            if (li.is_runtime_tables_selector_set) {
                if (!lookup_comms.is_runtime_set) {
                    revert("missing lookup runtime commitment");
                }
                PolyComm memory runtime = lookup_comms.runtime;
                if (!proof.evals.is_runtime_lookup_table_set) {
                    revert("missing runtime lookup table eval");
                }
                PointEvaluationsArray memory runtime_eval =
                    proof.evals.runtime_lookup_table;

                evaluations[eval_index++] = Evaluation(
                    runtime,
                    [runtime_eval.zeta, runtime_eval.zeta_omega],
                    0
                );
            }

            if (li.is_runtime_tables_selector_set) {
                Column memory col = Column(ColumnVariant.LookupRuntimeSelector, new bytes(0));
                PointEvaluationsArray memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] = Evaluation(
                    get_column_commitment(verifier_index, proof, col),
                    [eval.zeta, eval.zeta_omega],
                    0
                );
            }
            if (li.lookup_selectors.is_xor_set) {
                Column memory col =
                    Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Xor));
                PointEvaluationsArray memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] = Evaluation(
                    get_column_commitment(verifier_index, proof, col),
                    [eval.zeta, eval.zeta_omega],
                    0
                );
            }
            if (li.lookup_selectors.is_lookup_set) {
                Column memory col =
                    Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Lookup));
                PointEvaluationsArray memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] = Evaluation(
                    get_column_commitment(verifier_index, proof, col),
                    [eval.zeta, eval.zeta_omega],
                    0
                );
            }
            if (li.lookup_selectors.is_range_check_set) {
                Column memory col =
                    Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.RangeCheck));
                PointEvaluationsArray memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] = Evaluation(
                    get_column_commitment(verifier_index, proof, col),
                    [eval.zeta, eval.zeta_omega],
                    0
                );
            }
            if (li.lookup_selectors.is_ffmul_set) {
                Column memory col =
                    Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.ForeignFieldMul));
                PointEvaluationsArray memory eval = proof.evals.get_column_eval(col);
                evaluations[eval_index++] = Evaluation(
                    get_column_commitment(verifier_index, proof, col),
                    [eval.zeta, eval.zeta_omega],
                    0
                );
            }
        }

        // Scalar.FE[2] memory evaluation_points = [
        //     oracles.zeta,
        //     oracles.zeta.mul(verifier_index.domain_gen)
        // ];

        Scalar.FE[] memory evaluation_points = new Scalar.FE[](2);
        evaluation_points[0] = oracles.zeta;
        evaluation_points[1] = oracles.zeta.mul(verifier_index.domain_gen);
        return AggregatedEvaluationProof(evaluation_points, proof.opening);
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

    /// The polynomial that evaluates to each of `evals` for the respective `elm`s.
    function evalPolynomial(Scalar.FE[] memory elm, Scalar.FE[] memory evals)
        public
        pure
        returns (Polynomial.Dense memory)
    {
        require(elm.length == evals.length, "lengths don\'t match");
        require(elm.length == 2, "length must be 2");
        Scalar.FE zeta = elm[0];
        Scalar.FE zeta_omega = elm[1];
        Scalar.FE eval_zeta = evals[0];
        Scalar.FE eval_zeta_omega = evals[1];

        // The polynomial that evaluates to `p(zeta)` at `zeta` and `p(zeta_omega)` at
        // `zeta_omega`.
        // We write `p(x) = a + bx`, which gives
        // ```text
        // p(zeta) = a + b * zeta
        // p(zeta_omega) = a + b * zeta_omega
        // ```
        // and so
        // ```text
        // b = (p(zeta_omega) - p(zeta)) / (zeta_omega - zeta)
        // a = p(zeta) - b * zeta
        // ```

        // Compute b
        Scalar.FE num_b = eval_zeta_omega.add(eval_zeta.neg());
        Scalar.FE den_b_inv = zeta_omega.add(zeta.neg()).inv();
        Scalar.FE b = num_b.mul(den_b_inv);

        // Compute a
        Scalar.FE a = eval_zeta.sub(b.mul(zeta));

        Scalar.FE[] memory coeffs = new Scalar.FE[](2);
        coeffs[0] = a;
        coeffs[1] = b;
        return Polynomial.Dense(coeffs);
    }

    function combineCommitments(Evaluation[] memory evaluations, Scalar.FE polyscale, Scalar.FE rand_base)
        internal
        pure
        returns (BN254.G1Point[] memory, Scalar.FE[] memory)
    {
        uint256 vec_length = 0;
        // Calculate the max length of the points and scalars vectors
        // Iterate over the evaluations
        for (uint256 i = 0; i < evaluations.length; i++) {
            // Filter out evaluations with an empty commitment
            if (evaluations[i].commitment.unshifted.length == 0) {
                continue;
            }

            vec_length += evaluations[i].commitment.unshifted.length + 1;
        }
        BN254.G1Point[] memory points = new BN254.G1Point[](vec_length);
        Scalar.FE[] memory scalars = new Scalar.FE[](vec_length);
        uint256 index = 0; // index of the element to assign in the vectors

        // Initialize xi_i to 1
        Scalar.FE xi_i = Scalar.FE.wrap(1);

        // Iterate over the evaluations
        for (uint256 i = 0; i < evaluations.length; i++) {
            // Filter out evaluations with an empty commitment
            if (evaluations[i].commitment.unshifted.length == 0) {
                continue;
            }

            // iterating over the polynomial segments
            for (uint256 j = 0; j < evaluations[i].commitment.unshifted.length; j++) {
                // Add the scalar rand_base * xi_i to the scalars vector
                scalars[index] = rand_base.mul(xi_i);
                // Add the point to the points vector
                points[index] = evaluations[i].commitment.unshifted[j];

                // Multiply xi_i by polyscale
                xi_i = xi_i.mul(polyscale);

                // Increment the index
                index++;
            }

            // If the evaluation has a degree bound and a non-zero shifted commitment
            if (evaluations[i].degree_bound > 0 && evaluations[i].commitment.shifted.x != 0) {
                // Add the scalar rand_base * xi_i to the scalars vector
                scalars[index] = rand_base.mul(xi_i);
                // Add the point to the points vector
                points[index] = evaluations[i].commitment.shifted;

                // Multiply xi_i by polyscale
                xi_i = xi_i.mul(polyscale);
                // Increment the index
                index++;
            }
        }
        return (points, scalars);
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

    function final_verify(
        AggregatedEvaluationProof memory agg_proof,
        URSG2 memory verifier_urs,
        BN254.G1Point memory numerator // this is faked
    ) public view returns (bool) {
        // We'll do an incomplete verification in which we'll receive a faked
        // numerator commitment, with the objective of skipping most of the
        // partial verification for now.

        BN254.G1Point memory quotient = agg_proof.opening.quotient.unshifted[0];

        // The evaluation points are calculated executing a small part of the partial
        // verification (we only need to squeeze a challenge in the fiat-shamir step).

        Scalar.FE[] memory divisor_poly_coeffs = new Scalar.FE[](3);

        // The divisor polynomial is the poly that evaluates to 0 in the evaluation
        // points. Used for proving that the numerator is divisible by it.
        // So, this is: (x-a)(x-b) = x^2 - (a + b)x + ab
        // (there're only two evaluation points: a and b).
        Scalar.FE a = agg_proof.evaluation_points[0];
        Scalar.FE b = agg_proof.evaluation_points[1];

        divisor_poly_coeffs[0] = a.mul(b);
        divisor_poly_coeffs[1] = a.add(b).neg();
        divisor_poly_coeffs[2] = Scalar.one();

        require(verifier_urs.g.length == 3, "verifier_urs doesn\'t have 3 of points");

        BN254.G2Point memory divisor = naive_msm(verifier_urs.g, divisor_poly_coeffs);

        // quotient commitment needs to be negated. See the doc of pairingProd2().
        return BN254.pairingProd2(numerator, BN254.P2(), quotient.neg(), divisor);
    }

    /* TODO WIP
    function deserialize_proof(
        uint256[] calldata public_inputs,
        uint256[] calldata serialized_proof
    ) returns (Proof memory) {}
    */

    /// @notice This is used exclusively in `test_PartialVerify()`.
    function set_verifier_index_for_testing() public {
        verifier_index.max_poly_size = 1;
    }

    /// @notice store a mina state
    function store_state(bytes memory data) internal {
        state = MsgPk.deserializeState(data, 0);
    }

    /// @notice check if state is available
    function is_state_available() public view returns (bool) {
        return state_available;
    }

    error UnavailableState();

    /// @notice retrieves the base58 encoded creator's public key
    function retrieve_state_creator() public view returns (string memory) {
        if (!state_available) {
            revert UnavailableState();
        }
        return state.creator;
    }

    /// @notice retrieves the hash of the state after this block
    function retrieve_state_hash() public view returns (uint256) {
        if (!state_available) {
            revert UnavailableState();
        }
        return state.hash;
    }

    /// @notice retrieves the block height
    function retrieve_state_height() public view returns (uint256) {
        if (!state_available) {
            revert UnavailableState();
        }
        return state.block_height;
    }
}
