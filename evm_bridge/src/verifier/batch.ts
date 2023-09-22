import { Scalar } from "o1js";
import { Verifier, VerifierIndex } from './verifier.js'
import { PolyComm } from "../poly_commitment/commitment.js";
import { ProverProof, PointEvaluations } from "../prover/prover.js";

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
        let public_comm = PolyComm.msm(com, elm);
        let f_comm = verifier_index
            .srs
            .maskCustom(public_comm,
                new PolyComm([Scalar.from(1)], undefined))?.commitment;
        return f_comm;
        /*
          Check the length of evaluations inside the proof.
          Commit to the negated public input polynomial.
          Run the Fiat-Shamir argument.
          Combine the chunked polynomials’ evaluations (TODO: most likely only the quotient polynomial is chunked) with the right powers of $\zeta^n$ and $(\zeta * \omega)^n$.
          Compute the commitment to the linearized polynomial $f$. To do this, add the constraints of all of the gates, of the permutation, and optionally of the lookup. (See the separate sections in the constraints section.) Any polynomial should be replaced by its associated commitment, contained in the verifier index or in the proof, unless a polynomial has its evaluation provided by the proof in which case the evaluation should be used in place of the commitment.
          Compute the (chuncked) commitment of $ft$ (see Maller’s optimization).
          List the polynomial commitments, and their associated evaluations, that are associated to the aggregated evaluation proof in the proof:
              recursion
              public input commitment
              ft commitment (chunks of it)
              permutation commitment
              index commitments that use the coefficients
              witness commitments
              coefficient commitments
              sigma commitments
              lookup commitments
        */
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
