import { Field, Struct } from "o1js";
import { Point } from "./Point.js";
import srs_json from "../test/srs.json";

let g_json: string[][] = srs_json.g;
let h_json: string[] = srs_json.h;

export class SRS {
    g: Point[];
    h: Point;

    static createFromJSON() {
        let g: Point[] = g_json.map((g_i_json) => Point.createFromJSON(g_i_json));
        let h = Point.createFromJSON(h_json);
        return new SRS(g, h);
    }

    constructor(g: Point[], h: Point) {
        this.g = g;
        this.h = h;
    }
}
