import { Scalar } from "o1js"

/* The proof that the prover creates from a ProverIndex `witness`. */
export class ProverProof {
    evals: ProofEvaluations<PointEvaluations<Array<Scalar>>>
}

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
     generic_selector: Evals
    /* evaluation of the poseidon selector polynomial */
     poseidon_selector: Evals
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
    /* runtabime table polynomial*/
    runtime?: Evals
}

/*
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations<Evals> {
    /* evaluation at the challenge point zeta */
    zeta: Evals
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zeta_omega: Evals
}
