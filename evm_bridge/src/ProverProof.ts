import { Field, Struct } from "snarkyjs";
import { fieldFromHex } from "./utils.js";

export class ProverProof extends Struct({
    z1: Field,
    sg: Field
}) {
    static createFromJSON(proof: { z1: string, sg: string }) {
        return new ProverProof({
            z1: fieldFromHex(proof.z1),
            sg: fieldFromHex(proof.sg),
        });
    }
}
