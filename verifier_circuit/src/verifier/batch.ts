import { AggregatedEvaluationProof, Evaluation, PolyComm } from "../poly_commitment/commitment.js";
import { ProverProof, PointEvaluations, ProofEvaluations, Constants, Oracles } from "../prover/prover.js";
import { Verifier, VerifierIndex } from "./verifier.js";
import { ForeignGroup } from "o1js";
import { deserHexScalar } from "../serde/serde_proof.js";
import { Column, PolishToken } from "../prover/expr.js";
import { GateType } from "../circuits/gate.js";
import { powScalar } from "../util/scalar.js";
import { range } from "../util/misc.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { isErr, isOk, unwrap, verifierOk, VerifierResult} from "../error.js";
import { logField } from "../util/log.js";
import { fq_sponge_params } from "./sponge.js";

export class Context {
    verifier_index: VerifierIndex
    proof: ProverProof
    public_input: ForeignScalar[]

    constructor(verifier_index: VerifierIndex, proof: ProverProof, public_input: ForeignScalar[]) {
        this.verifier_index = verifier_index;
        this.proof = proof;
        this.public_input = public_input;
    }

    getColumn(col: Column): PolyComm<ForeignGroup> | undefined {
        switch (col.kind) {
            case "witness": return this.proof.commitments.wComm[col.index];
            case "coefficient": return this.verifier_index.coefficients_comm[col.index];
            case "permutation": return this.verifier_index.sigma_comm[col.index];
            case "z": return this.proof.commitments.zComm;
            case "index": {
                switch (col.typ) {
                    case GateType.Zero: return undefined;
                    case GateType.Generic: return this.verifier_index.generic_comm;
                    case GateType.CompleteAdd: return this.verifier_index.complete_add_comm;
                    case GateType.VarBaseMul: return this.verifier_index.psm_comm;
                    case GateType.EndoMul: return this.verifier_index.emul_comm;
                    case GateType.EndoMulScalar: return this.verifier_index.endomul_scalar_comm;
                    case GateType.Poseidon: return this.verifier_index.psm_comm;
                }
                break;
            }
        }
        return undefined;
    }
}

export class Batch {
    /**
     * will take verifier_index, proof and public inputs as args.
     * will output a "batch evaluation proof"
     *
     * essentially will partial verify proofs so they can be batched verified later.
    */
    static toBatch(verifier_index: VerifierIndex, proof: ProverProof, public_input: ForeignScalar[]): VerifierResult<AggregatedEvaluationProof> {
        //~ 1. Check the length of evaluations inside the proof.
        this.#check_proof_evals_len(proof)

        //~ 2. Commit to the negated public input polynomial.
        let lgr_comm = verifier_index.srs.lagrangeBases.get(verifier_index.domain_size)!;
        let com = lgr_comm?.slice(0, verifier_index.public);
        let elm = public_input.map(s => s.neg());
        let non_hiding_public_comm = PolyComm.msm(com, elm);
        let public_comm = verifier_index
            .srs
            .maskCustom(non_hiding_public_comm,
                new PolyComm([ForeignScalar.from(1)], undefined))?.commitment!;

        //~ 3. Run the Fiat-Shamir heuristic.
        const oracles_result = proof.oracles(verifier_index, public_comm, public_input);
        if (isErr(oracles_result)) return oracles_result;

        const {
            fq_sponge,
            oracles,
            all_alphas,
            public_evals,
            powers_of_eval_points_for_chunks,
            polys,
            zeta1: zeta_to_domain_size,
            ft_eval0,
            combined_inner_product
        } = unwrap(oracles_result);

        //~ 4. Combine the chunked polynomials' evaluations
        const evals = ProofEvaluations.combine(proof.evals, powers_of_eval_points_for_chunks);
        const context = new Context(verifier_index, proof, public_input);

        //~ 5. Compute the commitment to the linearized polynomial $f$ by adding
        // all constraints, in commitment form or evaluation if not present.

        // Permutation constraints
        const permutation_vanishing_polynomial = verifier_index.permutation_vanishing_polynomial_m
            .evaluate(oracles.zeta);
        const alpha_powers_result = all_alphas.getAlphas(
            { kind: "permutation" },
            Verifier.PERMUTATION_CONSTRAINTS
        );
        if (isErr(alpha_powers_result)) return alpha_powers_result;
        const alphas = unwrap(alpha_powers_result);

        let commitments = [verifier_index.sigma_comm[Verifier.PERMUTS - 1]];
        const init = evals.z.zetaOmega
            .mul(oracles.beta)
            .mul(alphas.next())
            .mul(permutation_vanishing_polynomial);
        let scalars: ForeignScalar[] = [evals.s
            .map((s, i) => oracles.gamma.add(oracles.beta.mul(s.zeta)).add(evals.w[i].zeta))
            .reduce((acc, curr) => acc.mul(curr), init)];

        const constants: Constants<ForeignScalar> = {
            alpha: oracles.alpha,
            beta: oracles.beta,
            gamma: oracles.gamma,
            endo_coefficient: verifier_index.endo,
            mds: fq_sponge_params().mds,
            zk_rows: verifier_index.zk_rows,
        }

        for (const [col, toks] of verifier_index.linearization.index_terms) {
            scalars.push(PolishToken.evaluate(
                toks,
                oracles.zeta,
                evals,
                verifier_index.domain_gen,
                verifier_index.domain_size,
                constants
            ));
            commitments.push(context.getColumn(col)!);
        }
        const f_comm = PolyComm.msm(commitments, scalars);

        //~ 6. Compute the (chuncked) commitment of $ft$ (see Maller’s optimization).
        const zeta_to_srs_len = powScalar(oracles.zeta, verifier_index.max_poly_size);
        const chunked_f_comm = PolyComm.chunk_commitment(f_comm, zeta_to_srs_len);
        const chunked_t_comm = PolyComm.chunk_commitment(proof.commitments.tComm, zeta_to_srs_len);
        const ft_comm = PolyComm.sub(
            chunked_f_comm,
            PolyComm.scale(
                chunked_t_comm,
                zeta_to_domain_size.sub(ForeignScalar.from(1))));

        //~ 7. List the polynomial commitments, and their associated evaluations,
        //~    that are associated to the aggregated evaluation proof in the proof:
        let evaluations: Evaluation[] = [];

        //recursion
        evaluations.concat(polys.map(([c, e]) => new Evaluation(c, e)));
        // public input
        evaluations.push(new Evaluation(public_comm, public_evals));
        // ft commitment (chunks)
        evaluations.push(new Evaluation(ft_comm, [[ft_eval0], [proof.ft_eval1]]));

        for (const col of [
            { kind: "z" },
            { kind: "index", typ: GateType.Generic },
            { kind: "index", typ: GateType.Poseidon },
            { kind: "index", typ: GateType.CompleteAdd },
            { kind: "index", typ: GateType.VarBaseMul },
            { kind: "index", typ: GateType.EndoMul },
            { kind: "index", typ: GateType.EndoMulScalar },
        ]
            .concat(range(Verifier.COLUMNS).map((i) => { return { kind: "witness", index: i } }))
            .concat(range(Verifier.COLUMNS).map((i) => { return { kind: "coefficient", index: i } }))
            .concat(range(Verifier.PERMUTS - 1).map((i) => { return { kind: "permutation", index: i } })) as Column[]
        ) {
            const eva = proof.evals.getColumn(col)!;
            evaluations.push(new Evaluation(context.getColumn(col)!, [eva?.zeta, eva?.zetaOmega]));
        }

        /*
            //~~ * optional gate commitments
            .chain(
                verifier_index
                    .range_check0_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::RangeCheck0)),
            )
            .chain(
                verifier_index
                    .range_check1_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::RangeCheck1)),
            )
            .chain(
                verifier_index
                    .foreign_field_add_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::ForeignFieldAdd)),
            )
            .chain(
                verifier_index
                    .foreign_field_mul_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::ForeignFieldMul)),
            )
            .chain(
                verifier_index
                    .xor_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::Xor16)),
            )
            .chain(
                verifier_index
                    .rot_comm
                    .as_ref()
                    .map(|_| Column::Index(GateType::Rot64)),
            )
            //~~ * lookup commitments
            //~
            .chain(
                verifier_index
                    .lookup_index
                    .as_ref()
                    .map(|li| {
                        // add evaluations of sorted polynomials
                        (0..li.lookup_info.max_per_row + 1)
                            .map(Column::LookupSorted)
                            // add evaluations of the aggreg polynomial
                            .chain([Column::LookupAggreg].into_iter())
                    })
                    .into_iter()
                    .flatten(),
            ) {
                let evals = proof
                    .evals
                    .get_column(col)
                    .ok_or(VerifyError::MissingEvaluation(col))?;
                evaluations.push(Evaluation {
                    commitment: context
                        .get_column(col)
                        .ok_or(VerifyError::MissingCommitment(col))?
                        .clone(),
                    evaluations: vec![evals.zeta.clone(), evals.zeta_omega.clone()],
                    degree_bound: None,
                });
            }

            if let Some(li) = &verifier_index.lookup_index {
                let lookup_comms = proof
                    .commitments
                    .lookup
                    .as_ref()
                    .ok_or(VerifyError::LookupCommitmentMissing)?;

                let lookup_table = proof
                    .evals
                    .lookup_table
                    .as_ref()
                    .ok_or(VerifyError::LookupEvalsMissing)?;
                let runtime_lookup_table = proof.evals.runtime_lookup_table.as_ref();

                // compute table commitment
                let table_comm = {
                    let joint_combiner = oracles
                        .joint_combiner
                        .expect("joint_combiner should be present if lookups are used");
                    let table_id_combiner = joint_combiner
                        .1
                        .pow([u64::from(li.lookup_info.max_joint_size)]);
                    let lookup_table: Vec<_> = li.lookup_table.iter().collect();
                    let runtime = lookup_comms.runtime.as_ref();

                    combine_table(
                        &lookup_table,
                        joint_combiner.1,
                        table_id_combiner,
                        li.table_ids.as_ref(),
                        runtime,
                    )
                };

                // add evaluation of the table polynomial
                evaluations.push(Evaluation {
                    commitment: table_comm,
                    evaluations: vec![lookup_table.zeta.clone(), lookup_table.zeta_omega.clone()],
                    degree_bound: None,
                });

                // add evaluation of the runtime table polynomial
                if li.runtime_tables_selector.is_some() {
                    let runtime = lookup_comms
                        .runtime
                        .as_ref()
                        .ok_or(VerifyError::IncorrectRuntimeProof)?;
                    let runtime_eval = runtime_lookup_table
                        .as_ref()
                        .map(|x| x.map_ref(&|x| x.clone()))
                        .ok_or(VerifyError::IncorrectRuntimeProof)?;

                    evaluations.push(Evaluation {
                        commitment: runtime.clone(),
                        evaluations: vec![runtime_eval.zeta, runtime_eval.zeta_omega],
                        degree_bound: None,
                    });
                }
            }

            for col in verifier_index
                .lookup_index
                .as_ref()
                .map(|li| {
                    (li.runtime_tables_selector
                        .as_ref()
                        .map(|_| Column::LookupRuntimeSelector))
                    .into_iter()
                    .chain(
                        li.lookup_selectors
                            .xor
                            .as_ref()
                            .map(|_| Column::LookupKindIndex(LookupPattern::Xor)),
                    )
                    .chain(
                        li.lookup_selectors
                            .lookup
                            .as_ref()
                            .map(|_| Column::LookupKindIndex(LookupPattern::Lookup)),
                    )
                    .chain(
                        li.lookup_selectors
                            .range_check
                            .as_ref()
                            .map(|_| Column::LookupKindIndex(LookupPattern::RangeCheck)),
                    )
                    .chain(
                        li.lookup_selectors
                            .ffmul
                            .as_ref()
                            .map(|_| Column::LookupKindIndex(LookupPattern::ForeignFieldMul)),
                    )
                })
                .into_iter()
                .flatten()
            {
                let evals = proof
                    .evals
                    .get_column(col)
                    .ok_or(VerifyError::MissingEvaluation(col))?;
                evaluations.push(Evaluation {
                    commitment: context
                        .get_column(col)
                        .ok_or(VerifyError::MissingCommitment(col))?
                        .clone(),
                    evaluations: vec![evals.zeta.clone(), evals.zeta_omega.clone()],
                    degree_bound: None,
                });
            }

        */


        // prepare for the opening proof verification
        let evaluation_points = [oracles.zeta, oracles.zeta.mul(verifier_index.domain_gen)];
        const agg_proof: AggregatedEvaluationProof = {
            sponge: fq_sponge,
            evaluations,
            evaluation_points,
            polyscale: oracles.v,
            evalscale: oracles.u,
            opening: proof.proof,
            combined_inner_product,
        };
        return verifierOk(agg_proof);
    }

    /*

/// This function verifies the batch of zk-proofs
///     proofs: vector of Plonk proofs
///     RETURN: verification status
///
/// # Errors
///
/// Will give error if `srs` of `proof` is invalid or `verify` process fails.
pub fn batch_verify<G, EFqSponge, EFrSponge, OpeningProof: OpenProof<G>>(
    group_map: &G::Map,
    proofs: &[Context<G, OpeningProof>],
) -> Result<()>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
    EFqSponge: Clone + FqSponge<G::BaseField, G, G::ScalarField>,
    EFrSponge: FrSponge<G::ScalarField>,
{
    //~ #### Batch verification of proofs
    //~
    //~ Below, we define the steps to verify a number of proofs
    //~ (each associated to a [verifier index](#verifier-index)).
    //~ You can, of course, use it to verify a single proof.
    //~

    //~ 1. If there's no proof to verify, the proof validates trivially.
    if proofs.is_empty() {
        return Ok(());
    }

    //~ 1. Ensure that all the proof's verifier index have a URS of the same length. (TODO: do they have to be the same URS though? should we check for that?)
    // TODO: Account for the different SRS lengths
    let srs = proofs[0].verifier_index.srs();
    for &Context { verifier_index, .. } in proofs {
        if verifier_index.srs().max_poly_size() != srs.max_poly_size() {
            return Err(VerifyError::DifferentSRS);
        }
    }

    //~ 1. Validate each proof separately following the [partial verification](#partial-verification) steps.
    let mut batch = vec![];
    for &Context {
        verifier_index,
        proof,
        public_input,
    } in proofs
    {
        batch.push(to_batch::<G, EFqSponge, EFrSponge, OpeningProof>(
            verifier_index,
            proof,
            public_input,
        )?);
    }

    //~ 1. Use the [`PolyCom.verify`](#polynomial-commitments) to verify the partially evaluated proofs.
    if OpeningProof::verify(srs, group_map, &mut batch, &mut thread_rng()) {
        Ok(())
    } else {
        Err(VerifyError::OpenProof)
    }
}


    /*
    * Enforce the length of evaluations inside the `proof`.
    * Atm, the length of evaluations(both `zeta` and `zeta_omega`) SHOULD be 1.
    * The length value is prone to future change.
    */
    static #check_proof_evals_len(proof: ProverProof): boolean {
        const {
            w,
            z,
            s,
            coefficients,
            genericSelector,
            poseidonSelector
        } = proof.evals;

        const valid_evals_len = (evals: PointEvaluations<Array<ForeignScalar>>): boolean =>
            evals.zeta.length === 1 && evals.zetaOmega.length === 1;

        // auxiliary
        let arrays = [w, s, coefficients];
        let singles = [z, genericSelector, poseidonSelector];

        // true if all evaluation lengths are valid
        return arrays.every((evals) => evals.every(valid_evals_len)) &&
            singles.every(valid_evals_len);

        // TODO: check the rest of evaluations (don't really needed for our purposes)
    }
}
