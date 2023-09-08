import { CircuitString, Field, Struct } from "o1js";
import srs_json from "../test/srs.json";
import { Point } from "./Point";

export class SRS extends Struct({ h: Field }) {
    static createFromJSON() {
        let h = Field(0);
        return new SRS({
            h
        });
    }

    static decompressPoint(compressed_point: CircuitString) {
        let y_sign = compressed_point.substring(0, 2);
        return new Point({ x: Field(0), y: Field(0) });
    }
}
