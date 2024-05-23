import { FieldBn254, Scalar, createForeignFieldBn254 } from "o1js";

export class ForeignScalar extends createForeignFieldBn254(Scalar.ORDER).AlmostReduced {
    static sizeInFields() {
        return ForeignScalar.provable.sizeInFields();
    }

    static fromFields(fields: FieldBn254[]): ForeignScalar {
        return ForeignScalar.provable.fromFields(fields);
    }

    static toFields(one: ForeignScalar): FieldBn254[] {
        return ForeignScalar.provable.toFields(one);
    }

    toFields() {
        return ForeignScalar.toFields(this);
    }
}
