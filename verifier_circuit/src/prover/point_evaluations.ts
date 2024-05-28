import { FieldBn254 } from "o1js";
import { scalarFromFields, pointEvaluationsArrayFromFields, arrayToFields } from "../field_serializable.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

/**
 * Evaluations of a polynomial at 2 points.
 */
export class PointEvaluations {
    /* evaluation at the challenge point zeta */
    zeta: ForeignScalar
    /* Evaluation at `zeta . omega`, the product of the challenge point and the group generator */
    zetaOmega: ForeignScalar

    constructor(zeta: ForeignScalar, zetaOmega: ForeignScalar) {
        this.zeta = zeta;
        this.zetaOmega = zetaOmega;
    }

    static fromFields(fields: FieldBn254[]) {
        let [zeta, zetaOmegaOffset] = scalarFromFields(fields, 0);
        let [zetaOmega, _] = scalarFromFields(fields, zetaOmegaOffset);

        return new PointEvaluations(zeta, zetaOmega);
    }

    toFields() {
        let zeta = this.zeta.toFields();
        let zetaOmega = this.zetaOmega.toFields();

        return [...zeta, ...zetaOmega];
    }

    static sizeInFields() {
        let zetaSize = ForeignScalar.sizeInFields();
        let zetaOmegaSize = ForeignScalar.sizeInFields();

        return zetaSize + zetaOmegaSize;
    }

    static optionalFromFields(fields: FieldBn254[]) {
        let [optionFlag, ...input] = fields;

        if (optionFlag.equals(0)) {
            return undefined;
        }

        return PointEvaluations.fromFields(input);
    }

    static optionalToFields(input?: PointEvaluations) {
        if (typeof input === "undefined") {
            // [option_flag, ...zeros]
            return Array(PointEvaluations.sizeInFields() + 1).fill(FieldBn254(0));
        }

        let fields = input?.toFields();

        return [FieldBn254(1), ...fields];
    }

    static optionalArrayFromFields(length: number, fields: FieldBn254[]) {
        let [optionFlag, ...input] = fields;

        if (optionFlag.equals(0)) {
            return undefined;
        }

        let [array, _] = pointEvaluationsArrayFromFields(input, length, 0);

        return array;
    }

    static optionalArrayToFields(length: number, input?: PointEvaluations[]) {
        if (typeof input === "undefined") {
            // [option_flag, ...zeros]
            return Array(PointEvaluations.sizeInFields() * length + 1).fill(FieldBn254(0));
        }

        let fields = arrayToFields(input);

        return [FieldBn254(1), ...fields];
    }
}
