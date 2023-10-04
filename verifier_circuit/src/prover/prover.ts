import { Polynomial } from "../polynomial.js"
import { Field, Group, Scalar } from "o1js"
import { PolyComm, bPoly, bPolyCoefficients } from "../poly_commitment/commitment";
import { getLimbs64 } from "../util/bigint";
import { Sponge } from "../verifier/sponge";
import { Verifier, VerifierIndex } from "../verifier/verifier.js";
import { invScalar, powScalar } from "../util/scalar.js";
import { GateType } from "../circuits/gate.js";
import { Alphas } from "../alphas.js";

/** The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<Scalar[]>>
    prev_challenges: RecursionChallenge[]
    commitments: ProverCommitments

    /** Required evaluation for Maller's optimization */
    ft_eval1: Scalar

    constructor(
        evals: ProofEvaluations<PointEvaluations<Scalar[]>>,
        prev_challenges: RecursionChallenge[],
        commitments: ProverCommitments
    ) {
        this.evals = evals;
        this.prev_challenges = prev_challenges;
        this.commitments = commitments;
    }

    /**
     * Will run the random oracle argument for removing prover-verifier interaction (Fiat-Shamir transform)
     */
    oracles(index: VerifierIndex, public_comm: PolyComm<Group>, public_input?: Scalar[]): OraclesResult {
        let sponge_test = new Sponge();
        const fields = [Field.from(1), Field.from(2)];
        fields.forEach((f) => {
            sponge_test.absorb(f);
        });

        const n = index.domain_size;
        const endo_r = Scalar.from("0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1");
        // FIXME: ^ currently hard-coded, refactor this in the future

        let chunk_size;
        if (index.domain_size < index.max_poly_size) {
            chunk_size = 1;
        } else {
            chunk_size = index.domain_size / index.max_poly_size;
        }

        let zk_rows = index.zk_rows;
        //~ 1. Setup the Fq-Sponge.
        let fq_sponge = new Sponge();

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
        // WARN: omitted lookup-related for now

        //~ 7. Sample $\beta$ with the Fq-Sponge.
        const beta = fq_sponge.challenge();

        //~ 8. Sample $\gamma$ with the Fq-Sponge.
        const gamma = fq_sponge.challenge();

        //~ 9. If using lookup, absorb the commitment to the aggregation lookup polynomial.
        // WARN: omitted lookup-related for now

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
        let fr_sponge = new Sponge();
        const digest = fq_sponge.digest();

        //~ 18. Squeeze the Fq-sponge and absorb the result with the Fr-Sponge.
        fr_sponge.absorbScalar(digest);

        //~ 19. Absorb the previous recursion challenges.
        // Note: we absorb in a new sponge here to limit the scope in which we need the
        // more-expensive 'optional sponge'.
        let fr_sponge_aux = new Sponge();
        this.prev_challenges.forEach((prev) => fr_sponge_aux.absorbScalars(prev.chals));
        fr_sponge.absorbScalar(fr_sponge_aux.digest());

        // prepare some often used values

        let zeta1 = powScalar(zeta, n);
        const zetaw = zeta.mul(index.domain_gen);
        const evaluation_points = [zeta, zetaw];
        const powers_of_eval_points_for_chunks: PointEvaluations<Scalar> = {
            zeta: powScalar(zeta, index.max_poly_size),
            zetaOmega: powScalar(zetaw, index.max_poly_size)
        };

        //~ 20. Compute evaluations for the previous recursion challenges.
        const polys: [PolyComm<Group>, Scalar[][]][] = this.prev_challenges.map((chal) => {
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

        let public_evals: Scalar[][] | undefined;
        if (this.evals.public_input) {
            public_evals = [this.evals.public_input.zeta, this.evals.public_input.zetaOmega];
        } else if (chunk_size > 1) {
            // FIXME: missing public input eval error
        } else if (public_input) {
            // compute Lagrange base evaluation denominators
            let w = [Scalar.from(1)];
            for (let i = 0; i < public_input.length; i++) {
                w.push(powScalar(index.domain_gen, i));
            }

            let zeta_minus_x = w.map((w_i) => zeta.sub(w_i));

            w.forEach((w_i) => zeta_minus_x.push(zetaw.sub(w_i)))

            zeta_minus_x = zeta_minus_x.map(invScalar);

            //~ 21. Evaluate the negated public polynomial (if present) at $\zeta$ and $\zeta\omega$.
            //  NOTE: this works only in the case when the poly segment size is not smaller than that of the domain.
            if (public_input.length === 0) {
                public_evals = [[Scalar.from(0)], [Scalar.from(0)]];
            } else {
                let pe_zeta = Scalar.from(0);
                const min_len = Math.min(
                    zeta_minus_x.length,
                    w.length,
                    public_input.length
                );
                for (let i = 0; i < min_len; i++) {
                    const p = public_input[i];
                    const l = zeta_minus_x[i];
                    const w_i = w[i];

                    pe_zeta = pe_zeta.add(l.neg().mul(p).mul(w_i));
                }
                const size_inv = invScalar(Scalar.from(index.domain_size));
                pe_zeta = pe_zeta.mul(zeta1.sub(Scalar.from(1))).mul(size_inv);

                let pe_zetaOmega = Scalar.from(0);
                const min_lenOmega = Math.min(
                    zeta_minus_x.length - public_input.length,
                    w.length,
                    public_input.length
                );
                for (let i = 0; i < min_lenOmega; i++) {
                    const p = public_input[i];
                    const l = zeta_minus_x[i + public_input.length];
                    const w_i = w[i];

                    pe_zetaOmega = pe_zetaOmega.add(l.neg().mul(p).mul(w_i));
                }
                pe_zetaOmega = pe_zetaOmega
                    .mul(powScalar(zetaw, n).sub(Scalar.from(1)))
                    .mul(size_inv);

                public_evals = [[pe_zeta], [pe_zetaOmega]];
            }
        } else {
            public_evals = undefined;
            // FIXME: missing public input eval error
        }

        //~ 22. Absorb the unique evaluation of ft: $ft(\zeta\omega)$.
        fr_sponge.absorbScalar(this.ft_eval1);

        //~ 23. Absorb all the polynomial evaluations in $\zeta$ and $\zeta\omega$:
        //~~ * the public polynomial
        //~~ * z
        //~~ * generic selector
        //~~ * poseidon selector
        //~~ * the 15 register/witness
        //~~ * 6 sigmas evaluations (the last one is not evaluated)

        fr_sponge.absorbScalars(public_evals![0]);
        fr_sponge.absorbScalars(public_evals![1]);
        fr_sponge.absorbEvals(this.evals)

        //~ 24. Sample $v'$ with the Fr-Sponge.
        const v_chal = new ScalarChallenge(fr_sponge.challenge());

        //~ 25. Derive $v$ from $v'$ using the endomorphism (TODO: specify).
        const v = v_chal.toField(endo_r);

        //~ 26. Sample $u'$ with the Fr-Sponge.
        const u_chal = new ScalarChallenge(fr_sponge.challenge());

        //~ 27. Derive $u$ from $u'$ using the endomorphism (TODO: specify).
        const u = u_chal.toField(endo_r);

        //~ 28. Create a list of all polynomials that have an evaluation proof.

        const evals = ProofEvaluations.combine(this.evals, powers_of_eval_points_for_chunks);

        //~ 29. Compute the evaluation of $ft(\zeta)$.
        const zkp = index.zkpm.evaluate(zeta);
        const zeta1m1 = zeta1.sub(Scalar.from(1));

        const PERMUTATION_CONSTRAINTS = 3; // FIXME: hardcoded here
        let alpha_powers = all_alphas.getAlphas({ kind: "permutation" }, PERMUTATION_CONSTRAINTS);
        const alpha0 = alpha_powers[0];
        const alpha1 = alpha_powers[1];
        const alpha2 = alpha_powers[2];

        const init = (evals.w[Verifier.PERMUTS - 1].zeta.add(gamma))
            .mul(evals.z.zetaOmega)
            .mul(alpha0)
            .mul(zkp);

        let ft_eval0: Scalar = evals.w
            .map((w, i) => (beta.mul(evals.s[i].zeta).add(w.zetaOmega).add(gamma)))
            .reduce((acc, curr) => acc.mul(curr), init);

        ft_eval0 = ft_eval0.sub(
            public_evals![0].length === 0 ? Scalar.from(0) : public_evals![0][0]
        );

        ft_eval0 = ft_eval0.sub(
            evals.w
                .map((w_i, i) => gamma.add(beta.mul(zeta).mul(index.shift[i])).add(w_i.zeta))
                .reduce((acc, curr) => acc.mul(curr), alpha0.mul(zkp).mul(evals.z.zeta))
        );

        const numerator = (zeta1m1.mul(alpha1).mul((zeta.sub(index.w))))
            .add(zeta1m1.mul(alpha2).mul(zeta.sub(Scalar.from(1))))
            .mul(Scalar.from(1).sub(evals.z.zeta));

        const denominator = invScalar(zeta.sub(index.w).mul(zeta.sub(Scalar.from(1))));
        // FIXME: if error when inverting, "negligible probability"

        ft_eval0 = ft_eval0.add(numerator.mul(denominator));

        const constants: Constants<Scalar> = {
            alpha,
            beta,
            gamma,
            endo_coefficient: index.endo,
            mds: [[]] // FIXME: empty for now, should be a sponge param
        }

        ft_eval0 = ft_eval0.sub(evaluate_rpn());

        //     ft_eval0 -= PolishToken::evaluate(
        //         &index.linearization.constant_term,
        //         index.domain,
        //         zeta,
        //         &evals,
        //         &constants,
        //     )
        //     .unwrap();

        //     ft_eval0
        // };
        polys

        const ft_eval0_a = [ft_eval0];
        const ft_eval1_a = [this.ft_eval1];
        let es: [Scalar[][], number | undefined][] = polys.map(([_, e]) => [e, undefined]);
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
        Array(Verifier.COLUMNS).fill({ kind: "witness" }).forEach(push_column_eval);
        Array(Verifier.COLUMNS).fill({ kind: "coefficient" }).forEach(push_column_eval);
        // FIXME: ignoring lookup

        const combined_inner_product = combinedInnerProduct(
            evaluation_points,
            v,
            u,
            es,
            index.srs.g.length
        );

        const oracles: RandomOracles = {
            //joint_combiner // FIXME: ignoring lookups
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

        const res: OraclesResult = {
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

        return res;
    }
}

export function combinedInnerProduct(
    evaluation_points: Scalar[],
    polyscale: Scalar,
    evalscale: Scalar,
    polys: [Scalar[][], number | undefined][],
    srs_length: number
): Scalar {
    let res = Scalar.from(0);
    let xi_i = Scalar.from(1);

    for (const [evals_tr, shifted] of polys.filter(([evals_tr, _]) => evals_tr[0].length != 0)) {
        const evals = [...Array(evals_tr[0].length).keys()]
            .map((i) => evals_tr.map((v) => v[i]));

        for (const evaluation of evals) {
            const term = Polynomial.buildAndEvaluate(evaluation, evalscale);
            res = res.add(xi_i.mul(term));
            xi_i = xi_i.mul(polyscale);
        }

        if (shifted) {
            let last_evals: Scalar[];
            if (shifted >= evals.length * srs_length) {
                last_evals = Array(evaluation_points.length).fill(Scalar.from(0));
            } else {
                last_evals = evals[evals.length - 1];
            }

            const shifted_evals = evaluation_points
                .map((elm, i) => powScalar(elm, (srs_length - (shifted % srs_length))).mul(last_evals[i]))

            res = res.add((xi_i.mul(Polynomial.buildAndEvaluate(shifted_evals, evalscale))));
            xi_i = xi_i.mul(polyscale);
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

/** A type representing one of the polynomials involved in the PLONK IOP */
export namespace Column {
    export type Witness = {
        kind: "witness"
        index: number
    }

    export type Z = {
        kind: "z"
    }

    export type Index = {
        kind: "index"
        typ: GateType
    }

    export type Coefficient = {
        kind: "coefficient"
        index: number
    }

    export type Permutation = {
        kind: "permutation"
        index: number
    }
}

export type Column =
    | Column.Witness
    | Column.Z
    | Column.Index
    | Column.Coefficient
    | Column.Permutation;

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
    /* lookup-related evaluations */
    lookup?: LookupEvaluations<Evals>
    /* evaluation of the generic selector polynomial */
    genericSelector: Evals
    /* evaluation of the poseidon selector polynomial */
    poseidonSelector: Evals

    constructor(
        w: Array<Evals>,
        z: Evals,
        s: Array<Evals>,
        coefficients: Array<Evals>,
        genericSelector: Evals,
        poseidonSelector: Evals,
        lookup?: LookupEvaluations<Evals>,
        public_input?: Evals,
    ) {
        this.w = w;
        this.z = z;
        this.s = s;
        this.coefficients = coefficients;
        this.lookup = lookup;
        this.genericSelector = genericSelector;
        this.poseidonSelector = poseidonSelector;
        this.public_input = public_input;
        return this;
    }

    // TODO: implement this!!!!
    /*
    Returns a new PointEvaluations struct with the combined evaluations.
    */
    combine_point_evaluations(): PointEvaluations<Evals> {
        let zeta: Evals = Scalar.from(0) as Evals;
        let zetaOmega: Evals = Scalar.from(0) as Evals;

        let ret = new PointEvaluations(zeta, zetaOmega);
        return ret;
    }

    map<Evals2>(f: (e: Evals) => Evals2): ProofEvaluations<Evals2> {
        let {
            w,
            z,
            s,
            coefficients,
            //lookup,
            genericSelector,
            poseidonSelector,
        } = this;

        let public_input = undefined;
        if (this.public_input) public_input = f(this.public_input);

        return new ProofEvaluations(
            w.map(f),
            f(z),
            s.map(f),
            coefficients.map(f),
            f(genericSelector),
            f(poseidonSelector),
            undefined, // FIXME: ignoring lookup
            public_input
        )
    }

    static combine(
        evals: ProofEvaluations<PointEvaluations<Scalar[]>>,
        pt: PointEvaluations<Scalar>
    ): ProofEvaluations<PointEvaluations<Scalar>> {
        return evals.map((orig) => new PointEvaluations(
            Polynomial.buildAndEvaluate(orig.zeta, pt.zeta),
            Polynomial.buildAndEvaluate(orig.zetaOmega, pt.zetaOmega)
        ));
    }

    evaluate_coefficients(point: Scalar): Scalar {
        let zero = Scalar.from(0);

        let coeffs = this.coefficients.map((value) => value as Scalar);
        let p = new Polynomial(coeffs);
        if (this.coefficients.length == 0) {
            return zero;
        }
        if (point == zero) {
            return this.coefficients[0] as Scalar;
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
            case "index": {
                if (col.typ === GateType.Generic) return this.genericSelector;
                if (col.typ === GateType.Poseidon) return this.poseidonSelector;
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
    chals: Scalar[]
    comm: PolyComm<Group>

    evals(
        max_poly_size: number,
        evaluation_points: Scalar[],
        powers_of_eval_points_for_chunks: Scalar[]
    ): Scalar[][] {
        const chals = this.chals;
        // Comment copied from Kimchi code:
        //
        // No need to check the correctness of poly explicitly. Its correctness is assured by the
        // checking of the inner product argument.
        const b_len = 1 << chals.length;
        let b: Scalar[] | undefined = undefined;

        return [0, 1, 2].map((i) => {
            const full = bPoly(chals, evaluation_points[i])
            if (max_poly_size === b_len) {
                return [full];
            }

            let betacc = Scalar.from(1);
            let diffs: Scalar[] = [];
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

                const ret = betacc.mul(b_j);
                betacc = betacc.mul(evaluation_points[i]);
                diffs.push(ret);
            }

            const diff = diffs.reduce((x, y) => x.add(y), Scalar.from(0));
            return [full.sub(diff.mul(powers_of_eval_points_for_chunks[i])), diff];
        });
    }
}

export class ProverCommitments {
    /* Commitments to the witness (execution trace) */
    wComm: PolyComm<Group>[]
    /* Commitment to the permutation */
    zComm: PolyComm<Group>
    /* Commitment to the quotient polynomial */
    tComm: PolyComm<Group>
    // TODO: lookup commitment
}

function getBit(limbs_lsb: bigint[], i: number): bigint {
    const limb = Math.floor(i / 64);
    const j = BigInt(i % 64);
    return (limbs_lsb[limb] >> j) & 1n;
    // FIXME: if it's negative, then >> will fill with ones
}

export class ScalarChallenge {
    chal: Scalar

    constructor(chal: Scalar) {
        this.chal = chal;
    }

    toFieldWithLength(length_in_bits: number, endo_coeff: Scalar): Scalar {
        const rep = this.chal.toBigInt();
        const rep_64_limbs = getLimbs64(rep);

        let a = Scalar.from(2);
        let b = Scalar.from(2);

        const one = Scalar.from(1);
        const negone = one.neg();
        for (let i = Math.floor(length_in_bits / 2) - 1; i >= 0; i--) {
            a = a.add(a);
            b = b.add(b);

            const r_2i = getBit(rep_64_limbs, 2 * i);
            const s = r_2i === 0n ? negone : one;

            if (getBit(rep_64_limbs, 2 * i + 1) === 0n) {
                b = b.add(s);
            } else {
                a = a.add(s);
            }
        }

        return a.mul(endo_coeff).add(b);
    }

    toField(endo_coeff: Scalar): Scalar {
        const length_in_bits = 64 * Sponge.CHALLENGE_LENGTH_IN_LIMBS;
        return this.toFieldWithLength(length_in_bits, endo_coeff);
    }
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
    //joint_combiner?: F // WARN: skipped lookups
    /** The endomorphism coefficient */
    endo_coefficient: F
    /** The MDS matrix */
    mds: F[][]
}

// TODO: implement this
/** Evaluates a reverse polish notation expression into a field element */
function evaluate_rpn(): Scalar {
    return Scalar.from(0);
}

export class RandomOracles {
    //joint_combiner // FIXME: ignoring for now
    beta: Scalar
    gamma: Scalar
    alpha_chal: ScalarChallenge
    alpha: Scalar
    zeta: Scalar
    v: Scalar
    u: Scalar
    zeta_chal: ScalarChallenge
    v_chal: ScalarChallenge
    u_chal: ScalarChallenge
}

/** The result of running the oracle protocol */
export class OraclesResult {
    /** A sponge that acts on the base field of a curve */
    fq_sponge: Sponge
    /** the last evaluation of the Fq-Sponge in this protocol */
    digest: Scalar
    /** the challenges produced in the protocol */
    oracles: RandomOracles
    /** the computed powers of alpha */
    all_alphas: Alphas
    /** public polynomial evaluations */
    public_evals: Scalar[][] // array of size 2 of vecs of scalar
    /** zeta^n and (zeta * omega)^n */
    powers_of_eval_points_for_chunks: PointEvaluations<Scalar>
    /** recursion data */
    polys: [PolyComm<Group>, Scalar[][]][]
    /** pre-computed zeta^n */
    zeta1: Scalar
    /** The evaluation f(zeta) - t(zeta) * Z_H(zeta) */
    ft_eval0: Scalar
    /** Used by the OCaml side */
    combined_inner_product: Scalar
}
