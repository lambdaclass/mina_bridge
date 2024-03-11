import { Field, createForeignField } from "o1js";

export class ForeignField extends createForeignField(Field.ORDER) {
    static sizeInFields() {
        return 3;
    }
}
