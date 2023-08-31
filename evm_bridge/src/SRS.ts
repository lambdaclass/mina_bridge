import { Field, Provable, Struct } from "snarkyjs";
import { FieldFromHex } from "./utils.js";

export class SRS extends Struct(
    { g: Provable.Array(Field, 256) }
) {
    static from(srs: { g: String[] }) {
        return new SRS({
            // Converts the first 256 elements of g from String to Field
            // TODO: We need a way to take into account the other elements from g
            g: Array.from(Array(256).keys()).map(i => FieldFromHex(srs.g[i]))
        });
    }
}
