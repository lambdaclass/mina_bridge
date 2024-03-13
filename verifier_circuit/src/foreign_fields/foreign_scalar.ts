import { FieldBn254, Scalar, createForeignFieldBn254 } from "o1js";

export class ForeignScalar extends createForeignFieldBn254(Scalar.ORDER).AlmostReduced {
    static sizeInFields() {
        return ForeignScalar.provable.sizeInFields();
    }

    static fromFields(fields: FieldBn254[]) {
        return ForeignScalar.provable.fromFields(fields);
    }

    static toFields(one: ForeignScalar) {
        return ForeignScalar.provable.toFields(one);
    }
}

export class ForeignScalarBn254 extends createForeignFieldBn254(Scalar.ORDER).AlmostReduced {
    static sizeInFields() {
        return ForeignScalarBn254.provable.sizeInFields();
    }

    static fromFields(fields: FieldBn254[]) {
        return ForeignScalarBn254.provable.fromFields(fields);
    }

    static toFields(one: ForeignScalarBn254) {
        return ForeignScalarBn254.provable.toFields(one);
    }

}
