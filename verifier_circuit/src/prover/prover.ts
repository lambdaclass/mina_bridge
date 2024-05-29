import { Polynomial } from "../polynomial.js"
import { FieldBn254, Scalar } from "o1js"
import { PolyComm, bPoly, bPolyCoefficients } from "../poly_commitment/commitment.js";
import { arrayToFields, pallasCommFromFields, pallasCommArrayFromFields } from "../field_serializable.js";
import { ScalarChallenge } from "../verifier/scalar_challenge.js";
import { Sponge } from "../verifier/sponge.js";
import { VerifierIndex } from "../verifier/verifier.js";
import { powScalar } from "../util/scalar.js";
import { Alphas } from "../alphas.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { ProverProof } from "./prover_proof.js";
import { PointEvaluations } from "./point_evaluations.js";

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

    constructor(sorted: PolyComm<ForeignPallas>[], aggreg: PolyComm<ForeignPallas>, runtime?: PolyComm<ForeignPallas>) {
        this.sorted = sorted;
        this.aggreg = aggreg;
        this.runtime = runtime;
    }

    static fromFields(fields: FieldBn254[]) {
        let [sorted, aggregOffset] = pallasCommArrayFromFields(fields, 1, 1, 0);
        let [aggreg, runtimeOffset] = pallasCommFromFields(fields, 1, aggregOffset);
        let [runtime, _] = pallasCommFromFields(fields, 1, runtimeOffset);

        return new LookupCommitments(sorted, aggreg, runtime);
    }

    toFields() {
        let sorted = arrayToFields(this.sorted);
        let aggreg = this.aggreg.toFields();
        let runtime = typeof this.runtime === "undefined" ? [] : this.runtime.toFields();

        return [...sorted, ...aggreg, ...runtime];
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
    powers_of_eval_points_for_chunks: PointEvaluations
    /** recursion data */
    polys: [PolyComm<ForeignPallas>, ForeignScalar[][]][]
    /** pre-computed zeta^n */
    zeta1: ForeignScalar
    /** The evaluation f(zeta) - t(zeta) * Z_H(zeta) */
    ft_eval0: ForeignScalar
    /** Used by the OCaml side */
    combined_inner_product: ForeignScalar
}
