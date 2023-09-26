import { Scalar } from "o1js"
import { VerifierIndex } from '../verifier/verifier.js'

/* The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<Array<Scalar>>>
}

export class Context {
    /* The [VerifierIndex] associated to the proof */
    verifier_index: VerifierIndex

    /* The proof to verify */
    proof: ProverProof

    /* The public input used in the creation of the proof */
    public_input: Scalar[]
};

/*
 * Polynomial evaluations contained in a `ProverProof`.
 * **Chunked evaluations** `Field` is instantiated with vectors with a length that equals the length of the chunk
 * **Non chunked evaluations** `Field` is instantiated with a field, so they are single-sized#[serde_as]
 */
export class ProofEvaluations<Evals> {
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

    constructor(w: Array<Evals>,
        z: Evals, s: Array<Evals>,
        coefficients: Array<Evals>,
        lookup: LookupEvaluations<Evals>,
        genericSelector: Evals,
        poseidonSelector: Evals) {
        this.w = w;
        this.z = z;
        this.s = s;
        this.coefficients = coefficients;
        this.lookup = lookup;
        this.genericSelector = genericSelector;
        this.poseidonSelector = poseidonSelector;
        return this;
    }

    // TODO: implement this!!!!
    combine(): boolean {
        return true;
    }

    evaluate(point: Scalar): Scalar {
        /*
        if self.is_zero() {
            return F::zero();
        } else if point.is_zero() {
            return self.coeffs[0];
        }
        self.internal_evaluate(point)
        */

        /*
        let zero = Scalar.from(0);
        if (this.coefficients.length == 0) {
            return zero;
        }
        if (point == zero) {
            return this.coefficients[0]; // TODO!!!
        }
        */
        return Scalar.from(0); // TODO!
    }

}

/*
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

/*
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: Evals
}
