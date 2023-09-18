import { Scalar } from "o1js";
import { Verifier } from './verifier'
import { PolyComm } from "../poly_commitment/commitment.js";
import { SRS } from '../SRS.js';

export class Batch extends Verifier {
    // will take verifier_index, proof and public inputs as args.
    // will output a "batch evaluation proof"
    //
    // essentially will partial verify proofs so they can be batched verified later.
    static to_batch(verifier_index: VerifierIndex, public_input: Scalar[]) {
        //~ 2. Commit to the negated public input polynomial.
        let lgr_comm = verifier_index.srs.lagrange_bases.get(verifier_index.domain_size)!;
        let com = lgr_comm?.slice(0, verifier_index.public);
        let elm = public_input.map(s => s.neg());
        let public_comm = PolyComm.msm(com, elm);
        let f_comm = verifier_index
            .srs
            .mask_custom(public_comm,
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
}

export class VerifierIndex {
    srs: SRS
    domain_size: number
    public: number
}
