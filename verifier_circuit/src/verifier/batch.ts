import { AggregatedEvaluationProof, Evaluation, PolyComm } from "../poly_commitment/commitment.js";
import { ProverProof, PointEvaluations, ProofEvaluations, Constants } from "../prover/prover.js";
import { Verifier, VerifierIndex } from "./verifier.js";
import { Group, Scalar } from "o1js";
import { deserHexScalar } from "../serde/serde_proof.js";
import { Column, PolishToken } from "../prover/expr.js";
import { GateType } from "../circuits/gate.js";
import { powScalar } from "../util/scalar.js";
import { range } from "../util/misc.js";

export class Context {
    verifier_index: VerifierIndex
    proof: ProverProof
    public_input: Scalar[]

    constructor(verifier_index: VerifierIndex, proof: ProverProof, public_input: Scalar[]) {
        this.verifier_index = verifier_index;
        this.proof = proof;
        this.public_input = public_input;
    }

    getColumn(col: Column): PolyComm<Group> | undefined {
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

export class Batch extends Verifier {
    /**
     * will take verifier_index, proof and public inputs as args.
     * will output a "batch evaluation proof"
     *
     * essentially will partial verify proofs so they can be batched verified later.
    */
    static toBatch(verifier_index: VerifierIndex, proof: ProverProof, public_input: Scalar[]) {
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
                new PolyComm([Scalar.from(1)], undefined))?.commitment!;

        //~ 3. Run the Fiat-Shamir heuristic.
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
        } = proof.oracles(verifier_index, public_comm, public_input);

        //~ 4. Combine the chunked polynomials' evaluations
        const evals = ProofEvaluations.combine(proof.evals, powers_of_eval_points_for_chunks);
        const context = new Context(verifier_index, proof, public_input);

        //~ 5. Compute the commitment to the linearized polynomial $f$ by adding
        // all constraints, in commitment form or evaluation if not present.

        // Permutation constraints
        const permutation_vanishing_polynomial = verifier_index.permutation_vanishing_polynomial_m
            .evaluate(oracles.zeta);
        const alphas = all_alphas.getAlphas(
            { kind: "permutation" },
            Verifier.PERMUTATION_CONSTRAINTS
        );

        let commitments = [verifier_index.sigma_comm[Verifier.PERMUTS - 1]];
        const init = evals.z.zetaOmega
            .mul(oracles.beta)
            .mul(alphas[0])
            .mul(permutation_vanishing_polynomial);
        let scalars: Scalar[] = [evals.s
            .map((s, i) => oracles.gamma.add(oracles.beta.mul(s.zeta)).add(evals.w[i].zeta))
            .reduce((acc, curr) => acc.mul(curr), init)];

        // FIXME: hardcoded for now, should be a sponge parameter.
        // this was generated from the verifier_circuit_tests/ crate.
        const mds = [
            [
                "4e59dd23f06c2400f3ba607d02926badee7add77d3544a307e7af417ddf7283e",
                "0026c37744e275497518904a3d4bd83f3d89f414c28ab292cbfc96b6ab06db30",
                "3a567f1bc5592630ba6ae6014d6c2e6efb3fab52815eff16608c051bbc104117"
            ].map(deserHexScalar),
            [
                "0ceb4a2b7e38fea058a153e390439d2e0dd5bc481d5ac08069140335a86fd312",
                "559c4de970165cd66fd0068edcbe3615c7af8b5e380c9f6ea7be69b38e7cb12a",
                "37854a5bdac3b836763e2ec95d0ca6d9e5b908e127f16a98135c16285391cc00"
            ].map(deserHexScalar),
            [
                "1bd343a1e09a4080831e5afbf0ca3d3a610c383b154643eb88666970d2a6d904",
                "24c37437a332198bd134339acfab5fee7fd2e4ab157d1fae8b7c31e3ee05a802",
                "bd7b2b50cd898d9badcb3d2787a7b98322bb00bc2ddfb6b11efddfc6e992b019"
            ].map(deserHexScalar)
        ];

        const constants: Constants<Scalar> = {
            alpha: oracles.alpha,
            beta: oracles.beta,
            gamma: oracles.gamma,
            endo_coefficient: verifier_index.endo,
            mds: mds,
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
                zeta_to_domain_size.sub(Scalar.from(1))));

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
        return agg_proof;
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
            lookup,
            genericSelector,
            poseidonSelector
        } = proof.evals;

        const valid_evals_len = (evals: PointEvaluations<Array<Scalar>>): boolean =>
            evals.zeta.length === 1 && evals.zetaOmega.length === 1;

        // auxiliary
        let arrays = [w, s, coefficients];
        let singles = [z, genericSelector, poseidonSelector];
        if (lookup) {
            const {
                sorted,
                aggreg,
                table,
                runtime
            } = lookup;

            arrays.push(sorted);
            singles.push(aggreg, table);
            if (runtime) singles.push(runtime);
        }

        // true if all evaluation lengths are valid
        return arrays.every((evals) => evals.every(valid_evals_len)) &&
            singles.every(valid_evals_len);
    }
}
