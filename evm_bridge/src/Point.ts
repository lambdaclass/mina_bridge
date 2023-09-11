import { Field, Struct } from "o1js";


export class Point extends Struct({
    x: Field,
    y: Field
}) {
    static createFromJSON(point_json: string[]) {
        return new Point({ x: Field.from("0x" + point_json[0]), y: Field.from("0x" + point_json[1]) });
    }
}
