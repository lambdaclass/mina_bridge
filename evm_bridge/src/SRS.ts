import srs_json from "../test/srs.json" assert { type: "json" };
import { Field, Group, Scalar } from "o1js";
import { BlindedCommitment, PolyComm } from "./poly_commitment/commitment";

let g_json: string[][] = srs_json.g;
let h_json: string[] = srs_json.h;

export class SRS {
    /// The vector of group elements for committing to polynomials in coefficient form
    g: Group[];
    /// A group element used for blinding commitments
    h: Group;
    /// Commitments to Lagrange bases, per domain size
    lagrange_bases: Map<number, PolyComm<Group>[]>

    static createFromJSON() {
        let g: Group[] = g_json.map((g_i_json) => this.#createGroupFromJSON(g_i_json));
        let h = this.#createGroupFromJSON(h_json);
        return new SRS(g, h);
    }

    static #createGroupFromJSON(group_json: string[]) {
        return Group({ x: Field.from(group_json[0]), y: Field.from(group_json[1]) });
    }

    constructor(g: Group[], h: Group) {
        this.g = g;
        this.h = h;
    }

    mask_custom(com: PolyComm<Group>, blinders: PolyComm<Scalar>): BlindedCommitment<Group, Scalar> | undefined {
        let unshifted = [];
        let shifted = undefined;

        for (let i = 0; i < com.unshifted.length; i++) {
            let g = com.unshifted[i];
            let b = blinders.unshifted[i];
            let g_masked = this.h.scale(b);
            g_masked.
            unshifted[i] = this.un
        }

        let commitment = new PolyComm<[Group, Scalar]>(unshifted, shifted);
        return undefined;
    }
    
    /// Turns a non-hiding polynomial commitment into a hidding polynomial commitment. Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
    //pub fn mask_custom(
    //    &self,
    //    com: PolyComm<G>,
    //    blinders: &PolyComm<G::ScalarField>,
    //) -> Result<BlindedCommitment<G>, CommitmentError> {
    //    let commitment = com
    //        .zip(blinders)
    //        .ok_or_else(|| CommitmentError::BlindersDontMatch(blinders.len(), com.len()))?
    //        .map(|(g, b)| {
    //            let mut g_masked = self.h.mul(b);
    //            g_masked.add_assign_mixed(&g);
    //            g_masked.into_affine()
    //        });
    //    Ok(BlindedCommitment {
    //        commitment,
    //        blinders: blinders.clone(),
    //    })
    //}
}
