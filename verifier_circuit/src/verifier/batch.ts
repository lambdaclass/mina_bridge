import { AggregatedEvaluationProof, Evaluation, PolyComm } from "../poly_commitment/commitment.js";
import { ProverProof, PointEvaluations, ProofEvaluations, Constants, Oracles } from "../prover/prover.js";
import { Verifier, VerifierIndex } from "./verifier.js";
import { Column, PolishToken } from "../prover/expr.js";
import { GateType } from "../circuits/gate.js";
import { powScalar } from "../util/scalar.js";
import { range } from "../util/misc.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { isErr, isOk, unwrap, verifierOk, VerifierResult} from "../error.js";
import { fq_sponge_params } from "./sponge.js";
import { AlphasIterator } from "../alphas.js";
import { LookupPattern } from "../lookups/lookups.js";

import { fp_sponge_initial_state, fp_sponge_params, fq_sponge_initial_state, Sponge } from "../verifier/sponge.js";

export class Context {
    verifier_index: VerifierIndex
    proof: ProverProof
    public_input: ForeignScalar[]

    constructor(verifier_index: VerifierIndex, proof: ProverProof, public_input: ForeignScalar[]) {
        this.verifier_index = verifier_index;
        this.proof = proof;
        this.public_input = public_input;
    }

    getColumn(col: Column): PolyComm<ForeignPallas> | undefined {
        switch (col.kind) {
            case "witness": return this.proof.commitments.wComm[col.index];
            case "coefficient": return this.verifier_index.coefficients_comm[col.index];
            case "permutation": return this.verifier_index.sigma_comm[col.index];
            case "z": return this.proof.commitments.zComm;
            case "lookupsorted": return this.proof.commitments.lookup?.sorted[col.index];
            case "lookupaggreg": return this.proof.commitments.lookup?.aggreg;
            case "lookupkindindex": {
                if (col.pattern === LookupPattern.Xor) return this.verifier_index.lookup_index?.lookup_selectors.xor;
                if (col.pattern === LookupPattern.Lookup) return this.verifier_index.lookup_index?.lookup_selectors.lookup;
                if (col.pattern === LookupPattern.RangeCheck) return this.verifier_index.lookup_index?.lookup_selectors.range_check;
                if (col.pattern === LookupPattern.ForeignFieldMul) return this.verifier_index.lookup_index?.lookup_selectors.ffmul;
                else return undefined
            }
            case "lookuptable": return undefined;
            case "lookupruntimeselector": return this.verifier_index.lookup_index?.runtime_tables_selector;
            case "lookupruntimetable": return this.proof.commitments.lookup?.runtime;
            case "index": {
                switch (col.typ) {
                    case GateType.Zero: return undefined;
                    case GateType.Generic: return this.verifier_index.generic_comm;
                    case GateType.Lookup: return undefined;
                    case GateType.CompleteAdd: return this.verifier_index.complete_add_comm;
                    case GateType.VarBaseMul: return this.verifier_index.psm_comm;
                    case GateType.EndoMul: return this.verifier_index.emul_comm;
                    case GateType.EndoMulScalar: return this.verifier_index.endomul_scalar_comm;
                    case GateType.Poseidon: return this.verifier_index.psm_comm;
                    case GateType.RangeCheck0: return this.verifier_index.range_check0_comm;
                    case GateType.RangeCheck1: return this.verifier_index.range_check1_comm;
                    case GateType.ForeignFieldAdd: return this.verifier_index.foreign_field_add_comm;
                    case GateType.ForeignFieldMul: return this.verifier_index.foreign_field_mul_comm;
                    case GateType.Xor16: return this.verifier_index.xor_comm;
                    case GateType.Rot64: return this.verifier_index.rot_comm;
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
                new PolyComm([ForeignScalar.from(1).assertAlmostReduced()], undefined))?.commitment!;

        //~ 3. Run the Fiat-Shamir heuristic.
        const oracles_result = proof.oracles(verifier_index, public_comm, public_input);

        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());
        let evaluation_points = [ForeignScalar.from(0), ForeignScalar.from(0)];
        let evaluations: Evaluation[] = [];
        const agg_proof: AggregatedEvaluationProof = {
            sponge: fq_sponge,
            evaluations,
            evaluation_points,
            polyscale: ForeignScalar.from(0),
            evalscale: ForeignScalar.from(0),
            opening: proof.proof,
            combined_inner_product: ForeignScalar.from(0),
        };
        return verifierOk(agg_proof);

        /*
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
        let scalars = [this.permScalars(
            evals,
            oracles.beta,
            oracles.gamma,
            alphas,
            permutation_vanishing_polynomial
        )];

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
                zeta_to_domain_size.sub(ForeignScalar.from(1).assertAlmostReduced()).assertAlmostReduced()));

        //~ 7. List the polynomial commitments, and their associated evaluations,
        //~    that are associated to the aggregated evaluation proof in the proof:
        let evaluations: Evaluation[] = [];

        //recursion
        evaluations.concat(polys.map(([c, e]) => new Evaluation(c, e)));
        // public input
        evaluations.push(new Evaluation(public_comm, public_evals));
        // ft commitment (chunks)
        evaluations.push(new Evaluation(ft_comm, [[ft_eval0], [proof.ft_eval1]]));

        let cols = [
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
        .concat(range(Verifier.PERMUTS - 1).map((i) => { return { kind: "permutation", index: i } })) as Column[];
        if (verifier_index.range_check0_comm) cols.push({ kind: "index", typ: GateType.RangeCheck0});
        if (verifier_index.range_check1_comm) cols.push({ kind: "index", typ: GateType.RangeCheck1});
        if (verifier_index.foreign_field_add_comm) cols.push({ kind: "index", typ: GateType.ForeignFieldAdd});
        if (verifier_index.foreign_field_mul_comm) cols.push({ kind: "index", typ: GateType.ForeignFieldMul});
        if (verifier_index.xor_comm) cols.push({ kind: "index", typ: GateType.Xor16});
        if (verifier_index.rot_comm) cols.push({ kind: "index", typ: GateType.Rot64});
        if (verifier_index.lookup_index) {
            const li = verifier_index.lookup_index!;
            cols.concat(range(li.lookup_info.max_per_row + 1).map((index) => { return { kind: "lookupsorted", index}}));
            cols.push({ kind: "lookupaggreg" });
        }

        for (const col of cols)
        {
            const eva = proof.evals.getColumn(col)!;
            evaluations.push(new Evaluation(
                context.getColumn(col)!,
                [eva?.zeta, eva?.zetaOmega]
            ));
        }

        if (verifier_index.lookup_index) {
            const li = verifier_index.lookup_index!;

            const lookup_comms = proof.commitments.lookup!;
            const lookup_table = proof.evals.lookupTable!;
            const runtime_lookup_table = proof.evals.runtimeLookupTable!;

            const joint_combiner = oracles.joint_combiner!;
            const table_id_combiner = powScalar(joint_combiner[1], li.lookup_info.max_joint_size);
            const runtime = lookup_comms.runtime!;

            const table_comm = this.combineTable(
                li.lookup_table,
                joint_combiner[1],
                table_id_combiner,
                li.table_ids,
                runtime
            );

            evaluations.push(new Evaluation(
                table_comm,
                [lookup_table.zeta, lookup_table.zetaOmega]
            ))

            if (li.runtime_tables_selector) {
                evaluations.push(new Evaluation(
                    lookup_comms.runtime!,
                    [runtime_lookup_table.zeta, runtime_lookup_table.zetaOmega]
                ));
            }

            const lookup_cols: Column[] = [];
            if (li.runtime_tables_selector) lookup_cols.push({ kind: "lookupruntimeselector" });
            if (li.lookup_selectors.xor) lookup_cols.push({ kind: "lookupkindindex", pattern: LookupPattern.Xor });
            if (li.lookup_selectors.lookup) lookup_cols.push({ kind: "lookupkindindex", pattern: LookupPattern.Lookup });
            if (li.lookup_selectors.range_check) lookup_cols.push({ kind: "lookupkindindex", pattern: LookupPattern.RangeCheck });
            if (li.lookup_selectors.ffmul) lookup_cols.push({ kind: "lookupkindindex", pattern: LookupPattern.ForeignFieldMul });
            for (const col of lookup_cols) {
                const evals = proof.evals.getColumn(col)!;
                evaluations.push(new Evaluation(
                    context.getColumn(col)!,
                    [evals.zeta, evals.zetaOmega]
                ));
            }
        }

        // prepare for the opening proof verification
        let evaluation_points = [oracles.zeta, oracles.zeta.mul(verifier_index.domain_gen).assertAlmostReduced()];
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
        */
    }

    static permScalars(
        e: ProofEvaluations<PointEvaluations<ForeignScalar>>,
        beta: ForeignScalar,
        gamma: ForeignScalar,
        alphas: AlphasIterator,
        zkp_zeta: ForeignScalar
    ): ForeignScalar {
        const alpha0 = alphas.next();
        alphas.next();
        alphas.next();

        let acc = e.z.zetaOmega.mul(beta).assertAlmostReduced().mul(alpha0).assertAlmostReduced().mul(zkp_zeta);
        for (let i = 0; i < Math.min(e.w.length, e.s.length); i++) {
            const w = e.w[i];
            const s = e.s[i];

            const res = gamma.add(beta.mul(s.zeta)).add(w.zeta);
            acc = acc.assertAlmostReduced().mul(res.assertAlmostReduced());
        }
        return acc.neg();
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

    static combineTable(
        columns: PolyComm<ForeignPallas>[],
        column_combiner: ForeignScalar,
        table_id_combiner: ForeignScalar,
        table_id_vector?: PolyComm<ForeignPallas>,
        runtime_vector?: PolyComm<ForeignPallas>,
    ): PolyComm<ForeignPallas> {
        let j = ForeignScalar.from(1).assertAlmostReduced();
        let scalars = [j];
        let commitments = [columns[0]];

        for (const comm of columns.slice(1)) {
            j = j.mul(column_combiner).assertAlmostReduced();
            scalars.push(j);
            commitments.push(comm);
        }

        if (table_id_vector) {
            const table_id = table_id_vector!;
            scalars.push(table_id_combiner);
            commitments.push(table_id);
        }

        if (runtime_vector) {
            const runtime = runtime_vector;
            scalars.push(column_combiner);
            commitments.push(runtime);
        }

        return PolyComm.msm(commitments, scalars);
    }
}
