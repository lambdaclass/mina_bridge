import { readFileSync } from "fs";
import { ProvableBn254, FieldBn254, PoseidonBn254 } from "o1js";
import { ProverCommitments } from "./prover_commitments.js";
import { VerifierResult, verifierErr } from "../error.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { OpeningProof } from "../poly_commitment/opening_proof.js";
import { ScalarChallenge } from "../verifier/scalar_challenge.js";
import { Sponge, fp_sponge_params, fp_sponge_initial_state, fq_sponge_params, fq_sponge_initial_state } from "../verifier/sponge.js";
import { VerifierIndex, Verifier } from "../verifier/verifier.js";
import { Oracles, RecursionChallenge } from "./prover.js";
import { ProofEvaluations } from "./prover_evaluations.js";

/** The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations
    prev_challenges: RecursionChallenge[]
    commitments: ProverCommitments
    /** Required evaluation for Maller's optimization */
    ft_eval1: ForeignScalar
    proof: OpeningProof

    constructor(
        evals: ProofEvaluations,
        prev_challenges: RecursionChallenge[],
        commitments: ProverCommitments,
        ft_eval1: ForeignScalar,
        proof: OpeningProof
    ) {
        this.evals = evals;
        this.prev_challenges = prev_challenges;
        this.commitments = commitments;
        this.ft_eval1 = ft_eval1;
        this.proof = proof;
    }

    /**
     * Will run the random oracle argument for removing prover-verifier interaction (Fiat-Shamir transform)
     */
    oracles(index: VerifierIndex, public_comm: PolyComm<ForeignPallas>, public_input?: ForeignScalar[]): VerifierResult<Oracles> {
        const n = index.domain_size;
        const endo_r = ForeignScalar.from("0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1");
        // FIXME: ^ currently hard-coded, refactor this in the future

        let chunk_size;
        if (index.domain_size < index.max_poly_size) {
            chunk_size = 1;
        } else {
            chunk_size = index.domain_size / index.max_poly_size;
        }

        const zk_rows = index.zk_rows;

        //~ 1. Setup the Fq-Sponge.
        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());

        //~ 2. Absorb the digest of the VerifierIndex.
        fq_sponge.absorb(index.digest());

        //~ 3. Absorb the commitments of the previous challenges with the Fq-sponge.
        this.prev_challenges.forEach(
            (challenge) => fq_sponge.absorbCommitment.bind(fq_sponge)(challenge.comm)
        );

        //~ 4. Absorb the commitment of the public input polynomial with the Fq-Sponge.
        fq_sponge.absorbCommitment(public_comm);

        //~ 5. Absorb the commitments to the registers / witness columns with the Fq-Sponge.
        this.commitments.wComm.forEach(fq_sponge.absorbCommitment.bind(fq_sponge));

        //~ 6. If lookup is used:
        let joint_combiner = undefined;
        if (index.lookup_index) {
            const l = index.lookup_index;
            const lookup_commits = this.commitments.lookup
            if (!lookup_commits) return verifierErr("missing lookup commitments");
            if (l.runtime_tables_selector) {
                const runtime_commit = lookup_commits.runtime;
                if (!runtime_commit) return verifierErr("incorrect runtime proof");
                fq_sponge.absorbCommitment(runtime_commit);
            }

            const zero = ProvableBn254.witness(ForeignScalar.provable, () => ForeignScalar.from(0).assertAlmostReduced());
            const joint_combiner_scalar = l.joint_lookup_used
                ? fq_sponge.challenge()
                : zero;
            const joint_combiner_chal = new ScalarChallenge(joint_combiner_scalar);
            const joint_combiner_field = joint_combiner_chal.toField(endo_r);
            joint_combiner = [joint_combiner_scalar, joint_combiner_field];

            lookup_commits.sorted.forEach(fq_sponge.absorbCommitment);
        }

        //~ 7. Sample $\beta$ with the Fq-Sponge.
        const beta = fq_sponge.challenge();

        //~ 8. Sample $\gamma$ with the Fq-Sponge.
        const gamma = fq_sponge.challenge();

        //~ 9. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        if (this.commitments.lookup) {
            fq_sponge.absorbCommitment(this.commitments.lookup.aggreg);
        }

        //~ 10. Absorb the commitment to the permutation trace with the Fq-Sponge.
        fq_sponge.absorbCommitment(this.commitments.zComm);

        //~ 11. Sample $\alpha'$ with the Fq-Sponge.
        const alpha_chal = new ScalarChallenge(fq_sponge.challenge());

        //~ 12. Derive $\alpha$ from $\alpha'$ using the endomorphism (TODO: details).
        const alpha = alpha_chal.toField(endo_r);

        //~ 13. Enforce that the length of the $t$ commitment is of size `PERMUTS`.
        if (this.commitments.tComm.unshifted.length !== Verifier.PERMUTS) {
            // FIXME: return error "incorrect commitment length of 't'"
        }

        //~ 14. Absorb the commitment to the quotient polynomial $t$ into the argument.
        fq_sponge.absorbCommitment(this.commitments.tComm);

        //~ 15. Sample $\zeta'$ with the Fq-Sponge.
        const zeta_chal = new ScalarChallenge(fq_sponge.challenge());

        //~ 16. Derive $\zeta$ from $\zeta'$ using the endomorphism (TODO: specify).
        const zeta = zeta_chal.toField(endo_r);

        //~ 17. Setup the Fr-Sponge.
        let fr_sponge = new Sponge(fq_sponge_params(), fq_sponge_initial_state());

        const digest = fq_sponge.digest();
        return verifierErr("a");
        /*

        //~ 18. Squeeze the Fq-sponge and absorb the result with the Fr-Sponge.
        fr_sponge.absorbFr(digest);

        //~ 19. Absorb the previous recursion challenges.
        // Note: we absorb in a new sponge here to limit the scope in which we need the
        // more-expensive 'optional sponge'.
        let fr_sponge_aux = new Sponge(fq_sponge_params(), fq_sponge_initial_state());
        this.prev_challenges.forEach((prev) => fr_sponge_aux.absorbScalars(prev.chals));
        fr_sponge.absorbFr(fr_sponge_aux.digest());

        // prepare some often used values

        let zeta1 = powScalar(zeta, n);
        const zetaw = zeta.mul(index.domain_gen).assertAlmostReduced();
        const evaluation_points = [zeta, zetaw];
        const powers_of_eval_points_for_chunks: PointEvaluations<ForeignScalar> = {
            zeta: powScalar(zeta, index.max_poly_size),
            zetaOmega: powScalar(zetaw, index.max_poly_size)
        };

        //~ 20. Compute evaluations for the previous recursion challenges.
        const polys: [PolyComm<ForeignPallas>, ForeignScalar[][]][] = this.prev_challenges.map((chal) => {
            const evals = chal.evals(
                index.max_poly_size,
                evaluation_points,
                [
                    powers_of_eval_points_for_chunks.zeta,
                    powers_of_eval_points_for_chunks.zetaOmega
                ]
            );
            return [chal.comm, evals];
        });

        // retrieve ranges for the powers of alphas
        let all_alphas = index.powers_of_alpha;
        all_alphas.instantiate(alpha);

        let public_evals: ForeignScalar[][] | undefined;
        if (this.evals.public_input) {
            public_evals = [this.evals.public_input.zeta, this.evals.public_input.zetaOmega];
        } else if (chunk_size > 1) {
            return verifierErr("missing public input evaluation");
        } else if (public_input) {
            // compute Lagrange base evaluation denominators

            // take first n elements of the domain, where n = public_input.length
            let w = [ForeignScalar.from(1).assertAlmostReduced()];
            for (let i = 0; i < public_input.length; i++) {
                w.push(powScalar(index.domain_gen, i));
            }

            let zeta_minus_x = w.map((w_i) => zeta.sub(w_i).assertAlmostReduced());

            w.forEach((w_i) => zeta_minus_x.push(zetaw.sub(w_i).assertAlmostReduced()))

            zeta_minus_x = zeta_minus_x.map(invScalar);

            //~ 21. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            //  NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
            if (public_input.length === 0) {
                public_evals = [[ForeignScalar.from(0)], [ForeignScalar.from(0)]];
            } else {
                let pe_zeta = ForeignScalar.from(0).assertAlmostReduced();
                const min_len = Math.min(
                    zeta_minus_x.length,
                    w.length,
                    public_input.length
                );
                for (let i = 0; i < min_len; i++) {
                    const p = public_input[i];
                    const l = zeta_minus_x[i];
                    const w_i = w[i];

                    pe_zeta = pe_zeta.add(l.neg().mul(p).assertAlmostReduced().mul(w_i)).assertAlmostReduced();
                }
                const size_inv = invScalar(ForeignScalar.from(index.domain_size));
                pe_zeta =
                    pe_zeta.mul(zeta1.sub(ForeignScalar.from(1).assertAlmostReduced()).assertAlmostReduced()).assertAlmostReduced()
                        .mul(size_inv).assertAlmostReduced();

                let pe_zetaOmega = ForeignScalar.from(0).assertAlmostReduced();
                const min_lenOmega = Math.min(
                    zeta_minus_x.length - public_input.length,
                    w.length,
                    public_input.length
                );
                for (let i = 0; i < min_lenOmega; i++) {
                    const p = public_input[i];
                    const l = zeta_minus_x[i + public_input.length];
                    const w_i = w[i];

                    pe_zetaOmega = pe_zetaOmega.add(l.neg().mul(p).assertAlmostReduced().mul(w_i)).assertAlmostReduced();
                }
                pe_zetaOmega = pe_zetaOmega
                    .mul(powScalar(zetaw, n).sub(ForeignScalar.from(1).assertAlmostReduced()).assertAlmostReduced()).assertAlmostReduced()
                    .mul(size_inv).assertAlmostReduced();

                public_evals = [[pe_zeta], [pe_zetaOmega]];
            }
        } else {
            return verifierErr("missing public input evaluation");
        }

        //~ 22. Absorb the unique evaluation of ft: $ft(\zeta\omega)$.
        fr_sponge.absorbFr(this.ft_eval1);

        //~ 23. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
        //~~ * the public polynomial
        //~~ * z
        //~~ * generic selector
        //~~ * poseidon selector
        //~~ * the 15 register/witness
        //~~ * 6 sigmas evaluations (the last one is not evaluated)

        fr_sponge.absorbMultipleFr(public_evals![0]);
        fr_sponge.absorbMultipleFr(public_evals![1]);
        ProvableBn254.asProver(() => fr_sponge.absorbEvals(this.evals));

        //~ 24. Sample $v'$ with the Fr-Sponge.
        const v_chal = new ScalarChallenge(
            ProvableBn254.witness(ForeignScalar.provable, () => fr_sponge.challenge())
        );

        //~ 25. Derive $v$ from $v'$ using the endomorphism (TODO: specify).
        const v = v_chal.toField(endo_r);

        //~ 26. Sample $u'$ with the Fr-Sponge.
        const u_chal = new ScalarChallenge(
            ProvableBn254.witness(ForeignScalar.provable, () => fr_sponge.challenge())
        );

        //~ 27. Derive $u$ from $u'$ using the endomorphism (TODO: specify).
        const u = u_chal.toField(endo_r);

        //~ 28. Create a list of all polynomials that have an evaluation proof.
        const evals = ProofEvaluations.combine(this.evals, powers_of_eval_points_for_chunks);
        // WARN: untested

        //~ 29. Compute the evaluation of $ft(\zeta)$.
        const permutation_vanishing_polynomial = index.permutation_vanishing_polynomial_m.evaluate(zeta);
        const zeta1m1 = zeta1.sub(ForeignScalar.from(1)).assertAlmostReduced();

        const alpha_powers_result = all_alphas.getAlphas({ kind: "permutation" }, Verifier.PERMUTATION_CONSTRAINTS);
        if (isErr(alpha_powers_result)) return alpha_powers_result;
        const alpha_powers = unwrap(alpha_powers_result);

        const alpha0 = alpha_powers.next();
        const alpha1 = alpha_powers.next();
        const alpha2 = alpha_powers.next();

        const init = (evals.w[Verifier.PERMUTS - 1].zeta.add(gamma)).assertAlmostReduced()
            .mul(evals.z.zetaOmega).assertAlmostReduced()
            .mul(alpha0).assertAlmostReduced()
            .mul(permutation_vanishing_polynomial).assertAlmostReduced();

        let ft_eval0: ForeignScalar = evals.s
            .map((s, i) => (beta.mul(s.zeta).add(evals.w[i].zeta).add(gamma).assertAlmostReduced()))
            .reduce((acc, curr) => acc.mul(curr).assertAlmostReduced(), init);

        ft_eval0 = ft_eval0.sub(
            public_evals![0].length === 0
                ? ForeignScalar.from(0)
                : new Polynomial(public_evals[0]).evaluate(powers_of_eval_points_for_chunks.zeta)
        ).assertAlmostReduced();

        ft_eval0 = ft_eval0.sub(
            index.shift
                .map((s, i) => gamma.add(beta.mul(zeta).assertAlmostReduced().mul(s)).add(evals.w[i].zeta).assertAlmostReduced())
                .reduce(
                    (acc, curr) => acc.mul(curr).assertAlmostReduced(),
                    alpha0.mul(permutation_vanishing_polynomial).assertAlmostReduced()
                        .mul(evals.z.zeta).assertAlmostReduced()
                )
        ).assertAlmostReduced();

        const numerator = (zeta1m1.mul(alpha1).assertAlmostReduced().mul((zeta.sub(index.w)).assertAlmostReduced()))
            .add(zeta1m1.mul(alpha2).assertAlmostReduced().mul(zeta.sub(ForeignScalar.from(1)).assertAlmostReduced())).assertAlmostReduced()
            .mul(ForeignScalar.from(1).sub(evals.z.zeta).assertAlmostReduced()).assertAlmostReduced();

        const denominator = invScalar(
            zeta.sub(index.w).assertAlmostReduced()
                .mul(zeta.sub(ForeignScalar.from(1)).assertAlmostReduced()).assertAlmostReduced());
        // FIXME: if error when inverting, "negligible probability"

        ft_eval0 = ft_eval0.add(numerator.mul(denominator)).assertAlmostReduced();

        const constants: Constants<ForeignScalar> = {
            alpha,
            beta,
            gamma,
            endo_coefficient: index.endo,
            joint_combiner: joint_combiner ? joint_combiner[1] : undefined,
            mds: fq_sponge_params().mds,
            zk_rows
        }

        ft_eval0 = ft_eval0.sub(PolishToken.evaluate(
            index.linearization.constant_term,
            zeta,
            evals,
            index.domain_gen,
            index.domain_size,
            constants
        )).assertAlmostReduced();

        const ft_eval0_a = [ft_eval0];
        const ft_eval1_a = [this.ft_eval1];
        let es: [ForeignScalar[][], number | undefined][] = polys.map(([_, e]) => [e, undefined]);
        es.push([public_evals!, undefined]);
        es.push([[ft_eval0_a, ft_eval1_a], undefined]);

        const push_column_eval = (col: Column) => {
            const evals = this
                .evals
                .getColumn(col)!;
            es.push([[evals.zeta, evals.zetaOmega], undefined]);
        };

        push_column_eval({ kind: "z" })
        push_column_eval({ kind: "index", typ: GateType.Generic })
        push_column_eval({ kind: "index", typ: GateType.Poseidon })
        push_column_eval({ kind: "index", typ: GateType.CompleteAdd })
        push_column_eval({ kind: "index", typ: GateType.VarBaseMul })
        push_column_eval({ kind: "index", typ: GateType.EndoMul })
        push_column_eval({ kind: "index", typ: GateType.EndoMulScalar })

        range(Verifier.COLUMNS)
            .map((i) => { return { kind: "witness", index: i } as Column })
            .forEach(push_column_eval);
        range(Verifier.COLUMNS)
            .map((i) => { return { kind: "coefficient", index: i } as Column })
            .forEach(push_column_eval);
        range(Verifier.PERMUTS - 1)
            .map((i) => { return { kind: "permutation", index: i } as Column })
            .forEach(push_column_eval);
        if (index.range_check0_comm) push_column_eval({ kind: "index", typ: GateType.RangeCheck0 });
        if (index.range_check1_comm) push_column_eval({ kind: "index", typ: GateType.RangeCheck1 });
        if (index.foreign_field_add_comm) push_column_eval({ kind: "index", typ: GateType.ForeignFieldAdd });
        if (index.foreign_field_mul_comm) push_column_eval({ kind: "index", typ: GateType.ForeignFieldMul });
        if (index.xor_comm) push_column_eval({ kind: "index", typ: GateType.Xor16 });
        if (index.rot_comm) push_column_eval({ kind: "index", typ: GateType.Rot64 });
        if (index.lookup_index) {
            const li = index.lookup_index;
            range(li.lookup_info.max_per_row + 1)
                .map((index) => { return { kind: "lookupsorted", index } as Column })
                .forEach(push_column_eval);
            [{ kind: "lookupaggreg", } as Column, { kind: "lookuptable" } as Column]
                .forEach(push_column_eval);
            if (li.runtime_tables_selector) push_column_eval({ kind: "lookupruntimetable" });
            if (this.evals.runtimeLookupTableSelector) push_column_eval({ kind: "lookupruntimeselector" });
            if (this.evals.xorLookupSelector) push_column_eval({ kind: "lookupkindindex", pattern: LookupPattern.Xor });
            if (this.evals.lookupGateLookupSelector) push_column_eval({ kind: "lookupkindindex", pattern: LookupPattern.Lookup });
            if (this.evals.rangeCheckLookupSelector) push_column_eval({ kind: "lookupkindindex", pattern: LookupPattern.RangeCheck });
            if (this.evals.foreignFieldMulLookupSelector) push_column_eval({ kind: "lookupkindindex", pattern: LookupPattern.ForeignFieldMul });
        }

        const combined_inner_product = combinedInnerProduct(
            evaluation_points,
            v,
            u,
            es,
            index.srs.g.length
        );

        const oracles: RandomOracles = {
            joint_combiner,
            beta,
            gamma,
            alpha_chal,
            alpha,
            zeta,
            v,
            u,
            zeta_chal,
            v_chal,
            u_chal
        }

        const result: Oracles = {
            fq_sponge,
            digest,
            oracles,
            all_alphas,
            public_evals: public_evals!,
            powers_of_eval_points_for_chunks,
            polys,
            zeta1,
            ft_eval0,
            combined_inner_product
        }

        return verifierOk(result);
        */
    }

    hash() {
        return ProvableBn254.witness(FieldBn254, () => {
            let fieldsStr: string[] = JSON.parse(readFileSync("./src/prover_proof_fields.json", "utf-8"));
            let fieldsRepr = fieldsStr.map(FieldBn254);
            return PoseidonBn254.hash(fieldsRepr);
        });
    }

    static fromFields(fields: FieldBn254[]) {
        let evalsEnd = ProofEvaluations.sizeInFields();
        let evals = ProofEvaluations.fromFields(fields.slice(0, evalsEnd));
        let commitmentsEnd = evalsEnd + ProverCommitments.sizeInFields();
        let commitments = ProverCommitments.fromFields(fields.slice(evalsEnd, commitmentsEnd));
        let ftEval1End = commitmentsEnd + ForeignScalar.sizeInFields();
        let ft_eval1 = ForeignScalar.fromFields(fields.slice(commitmentsEnd, ftEval1End));
        let proofEnd = ftEval1End + OpeningProof.sizeInFields();
        let proof = OpeningProof.fromFields(fields.slice(ftEval1End, proofEnd));

        // TODO: add `prev_challenges`
        return new ProverProof(evals, [], commitments, ft_eval1, proof);
    }

    toFields() {
        return ProverProof.toFields(this);
    }

    static toFields(one: ProverProof) {
        let evals = one.evals.toFields();
        let commitments = one.commitments.toFields();
        // TODO: add prev_challenges
        let ft_eval1 = one.ft_eval1.toFields();
        let proof = one.proof.toFields();

        return [...evals, ...commitments, ...ft_eval1, ...proof];
    }

    static sizeInFields() {
        let evalsSize = ProofEvaluations.sizeInFields();
        let commitmentsSize = ProverCommitments.sizeInFields();
        // TODO: add `prev_challenges`
        let ftEval1Size = ForeignScalar.sizeInFields();
        let proofSize = OpeningProof.sizeInFields();

        return evalsSize + commitmentsSize + ftEval1Size + proofSize;
    }

    static toAuxiliary() {
        return [];
    }

    static check() { }
}
