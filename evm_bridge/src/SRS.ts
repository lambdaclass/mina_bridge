import srs_json from "../test/srs.json" assert { type: "json" };
import lagrange_bases_json from "../test/lagrange_bases.json" assert { type: "json" };
import { Field, Group, Scalar } from "o1js";
import { BlindedCommitment, PolyComm } from "./poly_commitment/commitment";

let g_json: string[][] = srs_json.g;
let h_json: string[] = srs_json.h;

// based on the test's domain
interface LagrangeBaseJSON {
    "32": {
        unshifted: {
            x: string,
            y: string,
        }[],
        shifted: null
    }[]
}

export class SRS {
    /// The vector of group elements for committing to polynomials in coefficient form
    g: Group[];
    /// A group element used for blinding commitments
    h: Group;
    /// Commitments to Lagrange bases, per domain size
    lagrangeBases: Map<number, PolyComm<Group>[]>

    static createFromJSON() {
        let g: Group[] = g_json.map((g_i_json) => this.#createGroupFromJSON(g_i_json));
        let h = this.#createGroupFromJSON(h_json);
        return new SRS(g, h);
    }

    static #createGroupFromJSON(group_json: string[]) {
        return Group({ x: Field.from(group_json[0]), y: Field.from(group_json[1]) });
    }
    static #createLagrangeBasesFromJSON(json: LagrangeBaseJSON): Map<number, PolyComm<Group>[]> {
        let map_unshifted = (unshifted: { x: string, y: string }[]) =>
            unshifted.map(({ x, y }) => this.#createGroupFromJSON([x, y]))
        //let map_shifted = (shifted: { x: string, y: string } | undefined) =>
        //    shifted ? this.#createGroupFromJSON([shifted.x, shifted.y]) : undefined;
        let map_shifted = (_shifted: null) => undefined;

        let lagrange_bases = json[32].map(({ unshifted, shifted }) =>
            new PolyComm<Group>(map_unshifted(unshifted), map_shifted(shifted)));
        return new Map<number, PolyComm<Group>[]>([[32, lagrange_bases]]);
    }

    constructor(g: Group[], h: Group) {
        this.g = g;
        this.h = h;
        this.lagrangeBases = SRS.#createLagrangeBasesFromJSON(lagrange_bases_json);
    }

    /*
     * Turns a non-hiding polynomial commitment into a hidding polynomial commitment. Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
    */
    maskCustom(com: PolyComm<Group>, blinders: PolyComm<Scalar>): BlindedCommitment<Group, Scalar> | undefined {
        let commitment = com
            .zip(blinders)
            .map(([g, b]) => {
                let g_masked = this.h.scale(b);
                return g_masked.add(g);
            });
        return { commitment: commitment, blinders: blinders }
    }
}
