import srs_json from "../test/srs.json" assert { type: "json" };
import { Field, Group } from "o1js";

let g_json: string[][] = srs_json.g;
let h_json: string[] = srs_json.h;

export class SRS {
    g: Group[];
    h: Group;

    static createFromJSON() {
        let g: Group[] = g_json.map((g_i_json) => this.#createGroupFromJSON(g_i_json));
        let h = this.#createGroupFromJSON(h_json);
        return new SRS(g, h);
    }

    static #createGroupFromJSON(group_json: string[]) {
        return Group({ x: Field.from(group_json[0]), y: Field.from(group_json[1]) });
    }

    constructor(g: Group[], h: Group) {
        this.g = g;
        this.h = h;
    }
}
