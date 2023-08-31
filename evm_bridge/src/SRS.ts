import { Field, Provable, Struct } from "snarkyjs";
import { FieldFromHex } from "./utils.js";

export const G_SIZE = 512;

export class SRSWindow extends Struct(
    { g: Provable.Array(Field, G_SIZE) }
) {
    static from(srs: { g: String[] }, window: number) {
        return new SRSWindow({
            // Converts g[window], g[window + 1], ..., g[window + G_SIZE - 1] from String to Field
            g: Array.from(Array(G_SIZE).keys()).map(i => FieldFromHex(srs.g[i + window]))
        });
    }
}
