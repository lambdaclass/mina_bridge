import { CircuitString, Field, Struct } from "o1js";
import srs_json from "../test/srs.json";

export class SRS extends Struct({ h: Field }) {
    static createFromJSON() {
        let h;
        return new SRS({
            h
        });
    }

    static decompress_point(compressed_point: CircuitString) {
        let y_sign = compressed_point.substring(0, 2);
    }
}
