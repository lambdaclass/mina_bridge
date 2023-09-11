import { Field, Struct } from "o1js";
import { Point } from "./Point.js";
import srs_json from "../test/srs.json";

let h_json: string[] = srs_json.h;

export function createSRSFromJSON() {
    let h = new Point({ x: Field.from("0x" + h_json[0]), y: Field.from("0x" + h_json[1]) });
    return new SRS({
        h
    });
}

export class SRS extends Struct({ h: Point }) { }
