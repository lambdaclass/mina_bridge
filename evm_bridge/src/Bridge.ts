import { Bool, Circuit, circuitMain, public_ } from "snarkyjs";
import srs_json from "../test/srs.json" assert {type: "json"};
import { ProverProof } from "./ProverProof.js";
import { SRSWindow } from "./SRS.js";

const srs = Array.from(Array(srs_json.g.length / 512).keys()).map(i => SRSWindow.from(srs_json, i));

export class Bridge extends Circuit {
    @circuitMain
    static main(proof: ProverProof, @public_ isValidProof: Bool) {
        isValidProof.assertTrue();
    }
}
