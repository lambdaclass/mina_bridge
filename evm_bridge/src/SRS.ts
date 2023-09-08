import { CircuitString, Field, Struct } from "o1js";
import srs_json from "../test/srs.json";
import { Point } from "./Point";

let h_json: string[] = srs_json.h;

export class SRS extends Struct({ h: Point }) {
    static createFromJSON() {
        let h = new Point({ x: Field.from("0x" + h_json[0]), y: Field.from("0x" + h_json[1]) });
        return new SRS({
            h
        });
    }
}
