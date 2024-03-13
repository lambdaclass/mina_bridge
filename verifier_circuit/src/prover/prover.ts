import { Polynomial } from "../polynomial.js"
import { ProvableBn254, Scalar } from "o1js"
import { PolyComm, bPoly, bPolyCoefficients } from "../poly_commitment/commitment.js";
import { ScalarChallenge } from "../verifier/scalar_challenge.js";
import { fp_sponge_initial_state, fp_sponge_params, fq_sponge_initial_state, fq_sponge_params, Sponge } from "../verifier/sponge.js";
import { Verifier, VerifierIndex } from "../verifier/verifier.js";
import { invScalar, powScalar } from "../util/scalar.js";
import { GateType } from "../circuits/gate.js";
import { Alphas } from "../alphas.js";
import { Column, PolishToken } from "./expr.js";
import { range } from "../util/misc.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { VerifierResult, verifierErr, verifierOk, isErr, unwrap } from "../error.js";
import { LookupPattern } from "../lookups/lookups.js";
import { OpeningProof } from "../poly_commitment/opening_proof.js";

/** The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<ForeignScalar[]>>
    prev_challenges: RecursionChallenge[]
    commitments: ProverCommitments
    /** Required evaluation for Maller's optimization */
    ft_eval1: ForeignScalar
    proof: OpeningProof

    constructor(
        evals: ProofEvaluations<PointEvaluations<ForeignScalar[]>>,
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
}

export function combinedInnerProduct(
    evaluation_points: ForeignScalar[],
    polyscale: ForeignScalar,
    evalscale: ForeignScalar,
    polys: [ForeignScalar[][], number | undefined][],
    srs_length: number
): ForeignScalar {
    let res = ForeignScalar.from(0).assertAlmostReduced();
    let xi_i = ForeignScalar.from(1).assertAlmostReduced();

    for (const [evals_tr, shifted] of polys.filter(([evals_tr, _]) => evals_tr[0].length != 0)) {
        const evals = [...Array(evals_tr[0].length).keys()]
            .map((i) => evals_tr.map((v) => v[i]));

        for (const evaluation of evals) {
            const term = Polynomial.buildAndEvaluate(evaluation, evalscale);
            res = res.add(xi_i.mul(term)).assertAlmostReduced();
            xi_i = xi_i.mul(polyscale).assertAlmostReduced();
        }

        if (shifted) {
            let last_evals: ForeignScalar[];
            if (shifted >= evals.length * srs_length) {
                last_evals = Array(evaluation_points.length).fill(ForeignScalar.from(0));
            } else {
                last_evals = evals[evals.length - 1];
            }

            const shifted_evals = evaluation_points
                .map((elm, i) => powScalar(elm, (srs_length - (shifted % srs_length))).mul(last_evals[i]).assertAlmostReduced())

            res = res.add((xi_i.mul(Polynomial.buildAndEvaluate(shifted_evals, evalscale)))).assertAlmostReduced();
            xi_i = xi_i.mul(polyscale).assertAlmostReduced();
        }
    }
    return res;
}

export class Context {
    /* The [VerifierIndex] associated to the proof */
    verifier_index: VerifierIndex

    /* The proof to verify */
    proof: ProverProof

    /* The public input used in the creation of the proof */
    public_input: Scalar[]
};

/**
 * Polynomial evaluations contained in a `ProverProof`.
 * **Chunked evaluations** `Field` is instantiated with vectors with a length that equals the length of the chunk
 * **Non chunked evaluations** `Field` is instantiated with a field, so they are single-sized#[serde_as]
 */
export class ProofEvaluations<Evals> {
    /* public input polynomials */
    public_input?: Evals
    /* witness polynomials */
    w: Array<Evals> // of size 15, total num of registers (columns)
    /* permutation polynomial */
    z: Evals
    /*
     * permutation polynomials
     * (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
     */
    s: Array<Evals> // of size 7 - 1, total num of wirable registers minus one
    /* coefficient polynomials */
    coefficients: Array<Evals> // of size 15, total num of registers (columns)
    /* evaluation of the generic selector polynomial */
    genericSelector: Evals
    /* evaluation of the poseidon selector polynomial */
    poseidonSelector: Evals
    /** evaluation of the elliptic curve addition selector polynomial */
    completeAddSelector: Evals
    /** evaluation of the elliptic curve variable base scalar multiplication selector polynomial */
    mulSelector: Evals
    /** evaluation of the endoscalar multiplication selector polynomial */
    emulSelector: Evals
    /** evaluation of the endoscalar multiplication scalar computation selector polynomial */
    endomulScalarSelector: Evals

    // Optional gates
    /** evaluation of the RangeCheck0 selector polynomial **/
    rangeCheck0Selector?: Evals
    /** evaluation of the RangeCheck1 selector polynomial **/
    rangeCheck1Selector?: Evals
    /** evaluation of the ForeignFieldAdd selector polynomial **/
    foreignFieldAddSelector?: Evals
    /** evaluation of the ForeignFieldMul selector polynomial **/
    foreignFieldMulSelector?: Evals
    /** evaluation of the Xor selector polynomial **/
    xorSelector?: Evals
    /** evaluation of the Rot selector polynomial **/
    rotSelector?: Evals

    // lookup-related evaluations
    /** evaluation of lookup aggregation polynomial **/
    lookupAggregation?: Evals
    /** evaluation of lookup table polynomial **/
    lookupTable?: Evals
    /** evaluation of lookup sorted polynomials **/
    lookupSorted?: Evals[] // fixed size of 5
    /** evaluation of runtime lookup table polynomial **/
    runtimeLookupTable?: Evals

    // lookup selectors
    /** evaluation of the runtime lookup table selector polynomial **/
    runtimeLookupTableSelector?: Evals
    /** evaluation of the Xor range check pattern selector polynomial **/
    xorLookupSelector?: Evals
    /** evaluation of the Lookup range check pattern selector polynomial **/
    lookupGateLookupSelector?: Evals
    /** evaluation of the RangeCheck range check pattern selector polynomial **/
    rangeCheckLookupSelector?: Evals
    /** evaluation of the ForeignFieldMul range check pattern selector polynomial **/
    foreignFieldMulLookupSelector?: Evals

    constructor(
        w: Array<Evals>,
        z: Evals,
        s: Array<Evals>,
        coefficients: Array<Evals>,
        genericSelector: Evals,
        poseidonSelector: Evals,
        completeAddSelector: Evals,
        mulSelector: Evals,
        emulSelector: Evals,
        endomulScalarSelector: Evals,
        public_input?: Evals,
        rangeCheck0Selector?: Evals,
        rangeCheck1Selector?: Evals,
        foreignFieldAddSelector?: Evals,
        foreignFieldMulSelector?: Evals,
        xorSelector?: Evals,
        rotSelector?: Evals,
        lookupAggregation?: Evals,
        lookupTable?: Evals,
        lookupSorted?: Evals[], // fixed size of 5
        runtimeLookupTable?: Evals,
        runtimeLookupTableSelector?: Evals,
        xorLookupSelector?: Evals,
        lookupGateLookupSelector?: Evals,
        rangeCheckLookupSelector?: Evals,
        foreignFieldMulLookupSelector?: Evals,
    ) {
        this.w = w;
        this.z = z;
        this.s = s;
        this.coefficients = coefficients;
        this.genericSelector = genericSelector;
        this.poseidonSelector = poseidonSelector;
        this.completeAddSelector = completeAddSelector;
        this.mulSelector = mulSelector;
        this.emulSelector = emulSelector;
        this.endomulScalarSelector = endomulScalarSelector;
        this.public_input = public_input;
        this.rangeCheck0Selector = rangeCheck0Selector;
        this.rangeCheck1Selector = rangeCheck1Selector;
        this.foreignFieldAddSelector = foreignFieldAddSelector;
        this.foreignFieldMulSelector = foreignFieldMulSelector;
        this.xorSelector = xorSelector;
        this.rotSelector = rotSelector;
        this.lookupAggregation = lookupAggregation;
        this.lookupTable = lookupTable;
        this.lookupSorted = lookupSorted;
        this.runtimeLookupTable = runtimeLookupTable;
        this.runtimeLookupTableSelector = runtimeLookupTableSelector;
        this.xorLookupSelector = xorLookupSelector;
        this.lookupGateLookupSelector = lookupGateLookupSelector;
        this.rangeCheckLookupSelector = rangeCheckLookupSelector;
        this.foreignFieldMulLookupSelector = foreignFieldMulLookupSelector;
        return this;
    }

    map<Evals2>(f: (e: Evals) => Evals2): ProofEvaluations<Evals2> {
        let {
            w,
            z,
            s,
            coefficients,
            genericSelector,
            poseidonSelector,
            completeAddSelector,
            mulSelector,
            emulSelector,
            endomulScalarSelector,
            rangeCheck0Selector,
            rangeCheck1Selector,
            foreignFieldAddSelector,
            foreignFieldMulSelector,
            xorSelector,
            rotSelector,
            lookupAggregation,
            lookupTable,
            lookupSorted, // fixed size of 5
            runtimeLookupTable,
            runtimeLookupTableSelector,
            xorLookupSelector,
            lookupGateLookupSelector,
            rangeCheckLookupSelector,
            foreignFieldMulLookupSelector,
        } = this;

        let public_input = undefined;
        if (this.public_input) public_input = f(this.public_input);

        const optional_f = (e?: Evals) => e ? f(e) : undefined;

        return new ProofEvaluations<Evals2>(
            w.map(f),
            f(z),
            s.map(f),
            coefficients.map(f),
            f(genericSelector),
            f(poseidonSelector),
            f(completeAddSelector),
            f(mulSelector),
            f(emulSelector),
            f(endomulScalarSelector),
            public_input,
            optional_f(rangeCheck0Selector),
            optional_f(rangeCheck1Selector),
            optional_f(foreignFieldAddSelector),
            optional_f(foreignFieldMulSelector),
            optional_f(xorSelector),
            optional_f(rotSelector),
            optional_f(lookupAggregation),
            optional_f(lookupTable),
            lookupSorted ? lookupSorted!.map(f) : undefined, // fixed size of 5
            optional_f(runtimeLookupTable),
            optional_f(runtimeLookupTableSelector),
            optional_f(xorLookupSelector),
            optional_f(lookupGateLookupSelector),
            optional_f(rangeCheckLookupSelector),
            optional_f(foreignFieldMulLookupSelector),
        )
    }

    /*
    Returns a new PointEvaluations struct with the combined evaluations.
    */
    static combine(
        evals: ProofEvaluations<PointEvaluations<ForeignScalar[]>>,
        pt: PointEvaluations<ForeignScalar>
    ): ProofEvaluations<PointEvaluations<ForeignScalar>> {
        return evals.map((orig) => new PointEvaluations(
            Polynomial.buildAndEvaluate(orig.zeta, pt.zeta),
            Polynomial.buildAndEvaluate(orig.zetaOmega, pt.zetaOmega)
        ));
    }

    evaluate_coefficients(point: ForeignScalar): ForeignScalar {
        const zero = ForeignScalar.from(0);

        let coeffs = this.coefficients.map((value) => value as ForeignScalar);
        let p = new Polynomial(coeffs);
        if (this.coefficients.length == 0) {
            return zero;
        }
        if (point == zero) {
            return this.coefficients[0] as ForeignScalar;
        }
        return p.evaluate(point);
    }

    getColumn(col: Column): Evals | undefined {
        switch (col.kind) {
            case "witness": {
                return this.w[col.index];
            }
            case "z": {
                return this.z;
            }
            case "lookupsorted": {
                return this.lookupSorted?.[col.index];
            }
            case "lookupaggreg": {
                return this.lookupAggregation;
            }
            case "lookuptable": {
                return this.lookupTable;
            }
            case "lookupkindindex": {
                if (col.pattern === LookupPattern.Xor) return this.xorLookupSelector;
                if (col.pattern === LookupPattern.Lookup) return this.lookupGateLookupSelector;
                if (col.pattern === LookupPattern.RangeCheck) return this.rangeCheckLookupSelector;
                if (col.pattern === LookupPattern.ForeignFieldMul) return this.foreignFieldMulLookupSelector;
                else return undefined
            }
            case "lookupruntimeselector": {
                return this.runtimeLookupTableSelector;
            }
            case "lookupruntimetable": {
                return this.runtimeLookupTable;
            }
            case "index": {
                if (col.typ === GateType.Generic) return this.genericSelector;
                if (col.typ === GateType.Poseidon) return this.poseidonSelector;
                if (col.typ === GateType.CompleteAdd) return this.completeAddSelector;
                if (col.typ === GateType.VarBaseMul) return this.mulSelector;
                if (col.typ === GateType.EndoMul) return this.emulSelector;
                if (col.typ === GateType.EndoMulScalar) return this.endomulScalarSelector;
                if (col.typ === GateType.RangeCheck0) return this.rangeCheck0Selector;
                if (col.typ === GateType.RangeCheck1) return this.rangeCheck1Selector;
                if (col.typ === GateType.ForeignFieldAdd) return this.foreignFieldAddSelector;
                if (col.typ === GateType.ForeignFieldMul) return this.foreignFieldMulSelector;
                if (col.typ === GateType.Xor16) return this.xorSelector;
                if (col.typ === GateType.Rot64) return this.rotSelector;
                else return undefined;
            }
            case "coefficient": {
                return this.coefficients[col.index];
            }
            case "permutation": {
                return this.s[col.index];
            }
        }
    }
}

/**
 * Evaluations of lookup polynomials.
 */
export class LookupEvaluations<Evals> {
    /* sorted lookup table polynomial */
    sorted: Array<Evals>
    /* lookup aggregation polynomial */
    aggreg: Evals
    /* lookup table polynomial */
    table: Evals
    /* runtime table polynomial*/
    runtime?: Evals

    constructor() {
        this.sorted = [];
        return this;
    }
}

/**
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: Evals

    constructor(zeta: Evals, zetaOmega: Evals) {
        this.zeta = zeta;
        this.zetaOmega = zetaOmega;
    }
}

/**
 * Stores the challenges inside a `ProverProof`
 */
export class RecursionChallenge {
    chals: ForeignScalar[]
    comm: PolyComm<ForeignPallas>

    evals(
        max_poly_size: number,
        evaluation_points: ForeignScalar[],
        powers_of_eval_points_for_chunks: ForeignScalar[]
    ): ForeignScalar[][] {
        const chals = this.chals;
        // Comment copied from Kimchi code:
        //
        // No need to check the correctness of poly explicitly. Its correctness is assured by the
        // checking of the inner product argument.
        const b_len = 1 << chals.length;
        let b: ForeignScalar[] | undefined = undefined;

        return [0, 1, 2].map((i) => {
            const full = bPoly(chals, evaluation_points[i])
            if (max_poly_size === b_len) {
                return [full];
            }

            let betacc = ForeignScalar.from(1).assertAlmostReduced();
            let diffs: ForeignScalar[] = [];
            for (let j = max_poly_size; j < b_len; j++) {
                let b_j;
                if (b) {
                    b_j = b[j];
                } else {
                    const t = bPolyCoefficients(chals);
                    const res = t[j];
                    b = t;
                    b_j = res;
                }

                const ret = betacc.mul(b_j).assertAlmostReduced();
                betacc = betacc.mul(evaluation_points[i]).assertAlmostReduced();
                diffs.push(ret);
            }

            const diff = diffs.reduce((x, y) => x.add(y).assertAlmostReduced(), ForeignScalar.from(0).assertAlmostReduced());
            return [full.sub(diff.mul(powers_of_eval_points_for_chunks[i])).assertAlmostReduced(), diff];
        });
    }
}

/**
* Commitments linked to the lookup feature
*/
export class LookupCommitments {
    /// Commitments to the sorted lookup table polynomial (may have chunks)
    sorted: PolyComm<ForeignPallas>[]
    /// Commitment to the lookup aggregation polynomial
    aggreg: PolyComm<ForeignPallas>
    /// Optional commitment to concatenated runtime tables
    runtime?: PolyComm<ForeignPallas>
}

export class ProverCommitments {
    /* Commitments to the witness (execution trace) */
    wComm: PolyComm<ForeignPallas>[]
    /* Commitment to the permutation */
    zComm: PolyComm<ForeignPallas>
    /* Commitment to the quotient polynomial */
    tComm: PolyComm<ForeignPallas>
    /// Commitments related to the lookup argument
    lookup?: LookupCommitments
}

export class Constants<F> {
    /** The challenge alpha from the PLONK IOP. */
    alpha: F
    /** The challenge beta from the PLONK IOP. */
    beta: F
    /** The challenge gamma from the PLONK IOP. */
    gamma: F
    /**
     * The challenge joint_combiner which is used to combine
     * joint lookup tables.
     */
    joint_combiner?: F
    /** The endomorphism coefficient */
    endo_coefficient: F
    /** The MDS matrix */
    mds: F[][]
    /** The number of zero-knowledge rows */
    zk_rows: number
}

export class RandomOracles {
    joint_combiner?: ForeignScalar[]
    beta: ForeignScalar
    gamma: ForeignScalar
    alpha_chal: ScalarChallenge
    alpha: ForeignScalar
    zeta: ForeignScalar
    v: ForeignScalar
    u: ForeignScalar
    zeta_chal: ScalarChallenge
    v_chal: ScalarChallenge
    u_chal: ScalarChallenge
}

/** The result of running the oracle protocol */
export class Oracles {
    /** A sponge that acts on the base field of a curve */
    fq_sponge: Sponge
    /** the last evaluation of the Fq-Sponge in this protocol */
    digest: ForeignScalar
    /** the challenges produced in the protocol */
    oracles: RandomOracles
    /** the computed powers of alpha */
    all_alphas: Alphas
    /** public polynomial evaluations */
    public_evals: ForeignScalar[][] // array of size 2 of vecs of scalar
    /** zeta^n and (zeta * omega)^n */
    powers_of_eval_points_for_chunks: PointEvaluations<ForeignScalar>
    /** recursion data */
    polys: [PolyComm<ForeignPallas>, ForeignScalar[][]][]
    /** pre-computed zeta^n */
    zeta1: ForeignScalar
    /** The evaluation f(zeta) - t(zeta) * Z_H(zeta) */
    ft_eval0: ForeignScalar
    /** Used by the OCaml side */
    combined_inner_product: ForeignScalar
}
