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

using {BN254.neg} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {AlphasLib.get_alphas} for Alphas;
using {Polynomial.evaluate} for Polynomial.Dense;

library Kimchi {
    struct Proof {
        uint256 data;
    }

    struct ProofInput {
        uint256[] serializedProof;
    }

    struct ProverProof {
        // evals

        // opening proof
        BN254.G1Point opening_proof_quotient;
        uint256 opening_proof_blinding;
    }

    struct Evals {
        Base.FE zeta;
        Base.FE zeta_omega;
    }

    /*
    function deserializeEvals(
        uint8[71] calldata serialized_evals
    ) public view returns (Evals memory evals) {}
    */
}

contract KimchiVerifier {
    using {AlphasLib.register} for Alphas;
    using {combine_evals} for ProofEvaluationsArray;
    using {chunk_commitment} for PolyComm;

    VerifierIndex verifier_index;
    ProverProof proof;
    PairingURS urs;

    Sponge base_sponge;
    Sponge scalar_sponge;

    State internal state;
    bool state_available;

    function setup() public {
        //MsgPk.deser_pairing_urs(MsgPk.new_stream(urs_serialized), urs);
        // URS deserialization is WIP, we'll generate a random one for now:
        Scalar.FE x = Scalar.from(42);
        uint256 max_domain_size = 16384;
        urs.full_urs = create_trusted_setup(x, max_domain_size);
        urs.verifier_urs = create_trusted_setup(x, 3);

        verifier_index.powers_of_alpha.register(ArgumentType.GateZero, 21);
        verifier_index.powers_of_alpha.register(ArgumentType.Permutation, 3);

        // TODO: Investigate about linearization and write a proper function for this
        verifier_index.powers_of_alpha.register(ArgumentType.GateZero, Constants.VARBASEMUL_CONSTRAINTS);
        verifier_index.powers_of_alpha.register(ArgumentType.Permutation, Constants.PERMUTATION_CONSTRAINTS);
    }

    function verify_with_index(bytes calldata verifier_index_serialized, bytes calldata prover_proof_serialized)
        public
        returns (bool)
    {
        MsgPk.deser_verifier_index(MsgPk.new_stream(verifier_index_serialized), verifier_index);
        MsgPk.deser_prover_proof(MsgPk.new_stream(prover_proof_serialized), proof);

        //calculate_lagrange_bases(
        //    verifier_index.urs.g,
        //    verifier_index.urs.h,
        //    verifier_index.domain_size,
        //    verifier_index.urs.lagrange_bases_unshifted
        //);

        partial_verify(new Scalar.FE[](0));
        // final_verify();
        return false;
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
    function partial_verify(Scalar.FE[] memory public_inputs) public {
        // Commit to the negated public input polynomial.

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
            Scalar.FE[] memory blinders = new Scalar.FE[](
                public_comm_tmp.unshifted.length
            );
            for (uint256 i = 0; i < public_comm_tmp.unshifted.length; i++) {
                blinders[i] = Scalar.FE.wrap(1);
            }
            public_comm = mask_custom(urs.full_urs, public_comm_tmp, blinders).commitment;
        }

        // Execute fiat-shamir with a Keccak sponge

        Oracles.Result memory oracles_res =
            Oracles.fiat_shamir(proof, verifier_index, public_comm, public_inputs, true, base_sponge, scalar_sponge);
        Oracles.RandomOracles memory oracles = oracles_res.oracles;

        // Combine the chunked polynomials' evaluations

        ProofEvaluations memory evals = proof.evals.combine_evals(oracles_res.powers_of_eval_points_for_chunks);

        // Compute the commitment to the linearized polynomial $f$.
        Scalar.FE permutation_vanishing_polynomial = Polynomial.vanishes_on_last_n_rows(
            verifier_index.domain_gen, verifier_index.domain_size, verifier_index.zk_rows
        ).evaluate(oracles.zeta);

        Scalar.FE[] memory alphas =
            verifier_index.powers_of_alpha.get_alphas(ArgumentType.Permutation, Constants.PERMUTATION_CONSTRAINTS);

        Linearization memory linear = verifier_index.linearization;

        PolyComm[] memory commitments = new PolyComm[](linear.index_terms.length + 1);
        // FIXME: todo! initialize `commitments` with sigma_comm

        Scalar.FE[] memory scalars = new Scalar.FE[](linear.index_terms.length + 1);
        scalars[0] = perm_scalars(
            evals,
            oracles.beta,
            oracles.gamma,
            alphas, // FIXME: change for iterator to take into account previous alphas
            permutation_vanishing_polynomial
        );

        ExprConstants memory constants = ExprConstants(
            oracles.alpha,
            oracles.beta,
            oracles.gamma,
            Scalar.from(0), // FIXME: joint_combiner in fiat-shamir is missing
            Scalar.from(0), // FIXME: endo_coefficient in verifier_index is missing
            new Scalar.FE[](0), // FIXME: keccak sponge mds is missing (can a MDS matrix be defined for the keccak sponge?)
            verifier_index.zk_rows
        );

        for (uint256 i = 0; i < linear.index_terms.length; i++) {
            Column memory col = linear.index_terms[i].col;
            PolishToken[] memory tokens = linear.index_terms[i].coeff;

            Scalar.FE scalar =
                evaluate(tokens, verifier_index.domain_gen, verifier_index.domain_size, oracles.zeta, evals, constants);

            scalars[i + 1] = scalar;
            commitments[i + 1] = get_column(verifier_index, proof, col);
        }

        PolyComm memory f_comm = polycomm_msm(commitments, scalars);

        // Compute the chunked commitment of ft
        Scalar.FE zeta_to_srs_len = oracles.zeta.pow(verifier_index.max_poly_size);
        PolyComm memory chunked_f_comm = f_comm.chunk_commitment(zeta_to_srs_len);
        PolyComm memory chunked_t_comm = proof.commitments.t_comm.chunk_commitment(zeta_to_srs_len);
    }

    function perm_scalars(
        ProofEvaluations memory e,
        Scalar.FE beta,
        Scalar.FE gamma,
        Scalar.FE[] memory alphas, // array with the next 3 powers
        Scalar.FE zkp_zeta // TODO: make an AlphaIterator type.
    ) internal pure returns (Scalar.FE res) {
        require(alphas.length == 3, "not enough powers of alpha for permutation");
        // TODO: alphas should be an iterator

        res = e.z.zeta_omega.mul(beta).mul(alphas[0]).mul(zkp_zeta);
        uint256 len = Utils.min(e.w.length, e.s.length);
        for (uint256 i = 0; i < len; i++) {
            res = res.mul(gamma.add(beta.mul(e.s[i].zeta)).add(e.w[i].zeta));
        }
    }

    /// The polynomial that evaluates to each of `evals` for the respective `elm`s.
    function evalPolynomial(Scalar.FE[] memory elm, Scalar.FE[] memory evals)
        public
        view
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

    function final_verify(Scalar.FE[] memory public_inputs) public {
        /*
        pub fn verify(
            &self,
            srs: &PairingSRS<Pair>,           // SRS
            evaluations: &Vec<Evaluation<G>>, // commitments to the polynomials
            polyscale: G::ScalarField,        // scaling factor for polynoms
            elm: &[G::ScalarField],           // vector of evaluation points
        ) -> bool {
            let poly_commitment = {
                let mut scalars: Vec<F> = Vec::new();
                let mut points = Vec::new();
                combine_commitments(
                    evaluations,
                    &mut scalars,
                    &mut points,
                    polyscale,
                    F::one(), // TODO: This is inefficient
                );
                let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();

                VariableBaseMSM::multi_scalar_mul(&points, &scalars)
            };

            let evals = combine_evaluations(evaluations, polyscale);
            let blinding_commitment = srs.full_srs.h.mul(self.blinding);
            let divisor_commitment = srs
                .verifier_srs
                .commit_non_hiding(&divisor_polynomial(elm), 1, None)
                .unshifted[0];

            let eval_commitment = srs
                .full_srs
                .commit_non_hiding(&eval_polynomial(elm, &evals), 1, None)
                .unshifted[0]
                .into_projective();
            let numerator_commitment = { poly_commitment - eval_commitment - blinding_commitment };

            let numerator = Pair::pairing(
                numerator_commitment,
                Pair::G2Affine::prime_subgroup_generator(),
            );
            let scaled_quotient = Pair::pairing(self.quotient, divisor_commitment);
            numerator == scaled_quotient
        }
        */
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
