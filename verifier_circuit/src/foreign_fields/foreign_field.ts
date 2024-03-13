import { Field, createForeignFieldBn254 } from "o1js";

export class ForeignField extends createForeignFieldBn254(Field.ORDER) {
    static sizeInFields() {
        return 3;
    }
}
