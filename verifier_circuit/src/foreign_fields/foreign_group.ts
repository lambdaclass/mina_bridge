import { Struct } from "o1js";
import { ForeignField } from "./foreign_field.js";

export class ForeignGroup {
    x: ForeignField;
    y: ForeignField;

    constructor(x: ForeignField, y: ForeignField) {
        this.x = x;
        this.y = y;
    }

    static zero() {
        return new ForeignGroup(ForeignField.from(0), ForeignField.from(0));
    }

    assertEquals(g: ForeignGroup, message?: string) {
        let { x: x1, y: y1 } = this;
        let { x: x2, y: y2 } = g;

        x1.assertEquals(x2, message);
        y1.assertEquals(y2, message);
    }
}
