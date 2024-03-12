import lagrange_bases_json from "../test_data/lagrange_bases.json" assert { type: "json" };
import { BlindedCommitment, PolyComm } from "./poly_commitment/commitment.js";
import { readFileSync } from "fs";
import { ForeignBase } from "./foreign_fields/foreign_field.js";
import { Field, ForeignGroup } from "o1js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";

let srs_json;
try {
    srs_json = JSON.parse(readFileSync("./test_data/srs.json", "utf-8"));
} catch (e) {
    console.log("Using test SRS");
    srs_json = {
        g: [
            ["24533576165769248459550833334830854594262873459712423377895708212271843679280",
                "1491943283321085992458304042389285332496706344738505795532548822057073739620"]
        ],
        h: [
            "15427374333697483577096356340297985232933727912694971579453397496858943128065",
            "2509910240642018366461735648111399592717548684137438645981418079872989533888"
        ]
    };
}

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
    g: ForeignGroup[];
    /// A group element used for blinding commitments
    h: ForeignGroup;
    /// Commitments to Lagrange bases, per domain size
    lagrangeBases: Map<number, PolyComm<ForeignGroup>[]>

    static createFromJSON() {
        let g: ForeignGroup[] = g_json.map((g_i_json) => this.#createGroupFromJSON(g_i_json));
        let h = this.#createGroupFromJSON(h_json);
        return new SRS(g, h);
    }

    static #createGroupFromJSON(group_json: string[]) {
        return new ForeignGroup(ForeignBase.from(group_json[0]), ForeignBase.from(group_json[1]));
    }
    static #createLagrangeBasesFromJSON(json: LagrangeBaseJSON): Map<number, PolyComm<ForeignGroup>[]> {
        let map_unshifted = (unshifted: { x: string, y: string }[]) =>
            unshifted.map(({ x, y }) => this.#createGroupFromJSON([x, y]))
        //let map_shifted = (shifted: { x: string, y: string } | undefined) =>
        //    shifted ? this.#createGroupFromJSON([shifted.x, shifted.y]) : undefined;
        let map_shifted = (_shifted: null) => undefined;

        let lagrange_bases = json[32].map(({ unshifted, shifted }) =>
            new PolyComm<ForeignGroup>(map_unshifted(unshifted), map_shifted(shifted)));
        return new Map<number, PolyComm<ForeignGroup>[]>([[32, lagrange_bases]]);
    }

    constructor(g: ForeignGroup[], h: ForeignGroup) {
        this.g = g;
        this.h = h;
        this.lagrangeBases = SRS.#createLagrangeBasesFromJSON(lagrange_bases_json);
    }

    /*
     * Turns a non-hiding polynomial commitment into a hidding polynomial commitment. Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
    */
    maskCustom(com: PolyComm<ForeignGroup>, blinders: PolyComm<ForeignScalar>): BlindedCommitment<ForeignGroup, ForeignScalar> | undefined {
        let commitment = com
            .zip(blinders)
            .map(([g, b]) => {
                let g_masked = this.h.scale(b);
                return g_masked.add(g);
            });
        return { commitment: commitment, blinders: blinders }
    }
}
