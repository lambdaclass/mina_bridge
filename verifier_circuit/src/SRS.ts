import lagrange_bases_json from "../test_data/lagrange_bases.json" assert { type: "json" };
import { BlindedCommitment, PolyComm } from "./poly_commitment/commitment.ts";
import { readFileSync } from "https://deno.land/std@0.51.0/fs/mod.ts";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.ts";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.ts";

let srs_json;
try {
    console.log("Using SRS file");
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
    g: ForeignPallas[];
    /// A group element used for blinding commitments
    h: ForeignPallas;
    /// Commitments to Lagrange bases, per domain size
    lagrangeBases: Map<number, PolyComm<ForeignPallas>[]>

    static createFromJSON() {
        let g: ForeignPallas[] = g_json.map((g_i_json) => this.#createGroupFromJSON(g_i_json));
        let h = this.#createGroupFromJSON(h_json);
        return new SRS(g, h);
    }

    static #createGroupFromJSON(group_json: string[]) {
        return new ForeignPallas({ x: BigInt(group_json[0]), y: BigInt(group_json[1]) });
    }
    static #createLagrangeBasesFromJSON(json: LagrangeBaseJSON): Map<number, PolyComm<ForeignPallas>[]> {
        let map_unshifted = (unshifted: { x: string, y: string }[]) =>
            unshifted.map(({ x, y }) => this.#createGroupFromJSON([x, y]))
        //let map_shifted = (shifted: { x: string, y: string } | undefined) =>
        //    shifted ? this.#createGroupFromJSON([shifted.x, shifted.y]) : undefined;
        let map_shifted = (_shifted: null) => undefined;

        let lagrange_bases = json[32].map(({ unshifted, shifted }) =>
            new PolyComm<ForeignPallas>(map_unshifted(unshifted), map_shifted(shifted)));
        return new Map<number, PolyComm<ForeignPallas>[]>([[32, lagrange_bases]]);
    }

    constructor(g: ForeignPallas[], h: ForeignPallas) {
        this.g = g;
        this.h = h;
        this.lagrangeBases = SRS.#createLagrangeBasesFromJSON(lagrange_bases_json);
    }

    /*
     * Turns a non-hiding polynomial commitment into a hidding polynomial commitment. Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
    */
    maskCustom(com: PolyComm<ForeignPallas>, blinders: PolyComm<ForeignScalar>): BlindedCommitment<ForeignPallas, ForeignScalar> | undefined {
        let commitment = com.zip_and_map(blinders, ([g, b]) => {
            let g_masked = this.h.scale(b);
            return g_masked.completeAdd(g) as ForeignPallas;
        })
        return { commitment: commitment, blinders: blinders }
    }
}
