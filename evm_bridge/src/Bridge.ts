import { Bool, Circuit, circuitMain, public_ } from "snarkyjs";
import { ProverProof } from "./ProverProof.js";

export class Bridge extends Circuit {
    @circuitMain
    static main(proof: ProverProof, @public_ isValidProof: Bool) {
        isValidProof.assertTrue();
    }
}
