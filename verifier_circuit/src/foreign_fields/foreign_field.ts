import { Field, createForeignFieldBn254 } from "o1js";

export class ForeignBase extends createForeignFieldBn254(Field.ORDER).AlmostReduced {
    static sizeInFields() {
        return 3;
    }
}
