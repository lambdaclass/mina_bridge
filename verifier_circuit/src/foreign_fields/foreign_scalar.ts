import { Field, Scalar, createForeignField } from "o1js";

export class ForeignScalar extends createForeignField(Scalar.ORDER).AlmostReduced {
    static sizeInFields() {
        return ForeignScalar.provable.sizeInFields();
    }

    static fromFields(fields: Field[]) {
        return ForeignScalar.provable.fromFields(fields);
    }

    static toFields(one: ForeignScalar) {
        return ForeignScalar.provable.toFields(one);
    }

}

