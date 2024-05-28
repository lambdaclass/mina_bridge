import { FieldBn254 } from "o1js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.js";
import { PolyComm } from "./poly_commitment/commitment.js";
import { PointEvaluations } from "./prover/prover.js";

export abstract class FieldSerializable {
    static fromFields: (_fields: FieldBn254[]) => FieldSerializable;
    toFields: () => FieldBn254[];
}

// - Item deserialization functions

/**
 * Returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ForeignScalar` 
 * in fields.
 */
export function scalarFromFields(fields: FieldBn254[], offset: number): [ForeignScalar, number] {
    let newOffset = offset + ForeignScalar.sizeInFields();
    let foreignScalar = ForeignScalar.fromFields(fields.slice(offset, newOffset));

    return [foreignScalar, newOffset];
}

/**
 * Returns `[point, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ForeignPallas` 
 * in fields.
 */
export function pallasFromFields(fields: FieldBn254[], offset: number): [ForeignPallas, number] {
    let newOffset = offset + ForeignPallas.sizeInFields();
    let foreignPallas = ForeignPallas.fromFields(fields.slice(offset, newOffset));

    return [foreignPallas, newOffset];
}

/**
 * Returns `[commitment, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PolyComm` 
 * in fields.
 */
export function pallasCommFromFields(fields: FieldBn254[], length: number, offset: number): [PolyComm<ForeignPallas>, number] {
    let pallasComm = PolyComm.fromFields(fields, length);
    let newOffset = offset + PolyComm.sizeInFields(length);

    return [pallasComm, newOffset];
}

/**
 * Returns `[evals, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PointEvaluations` 
 * in fields.
 */
export function pointEvaluationsFromFields(fields: FieldBn254[], offset: number): [PointEvaluations, number] {
    let pointEvaluations = PointEvaluations.fromFields(fields);
    let newOffset = offset + PointEvaluations.sizeInFields();

    return [pointEvaluations, newOffset];
}

// - Array deserialization functions

export function arrayToFields(input: FieldSerializable[]) {
    return input.map((item) => item.toFields()).reduce((acc, fields) => acc.concat(fields), []);
}

/**
 * Returns `[points, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function pallasArrayFromFields(fields: FieldBn254[], length: number, offset: number): [ForeignPallas[], number] {
    let cursor = offset;
    let foreignPallasArray = [];
    for (let i = 0; i < length; i++) {
        let [foreignPallas, newStart] = pallasFromFields(fields, cursor);
        foreignPallasArray.push(foreignPallas);
        cursor = newStart;
    }

    return [foreignPallasArray, cursor];
}

/**
 * Returns `[commitments, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function pallasCommArrayFromFields(fields: FieldBn254[], arrayLength: number, commLength: number, offset: number): [PolyComm<ForeignPallas>[], number] {
    let cursor = offset;
    let pallasCommArray = [];
    for (let i = 0; i < arrayLength; i++) {
        let [foreignPallas, newStart] = pallasCommFromFields(fields, commLength, cursor);
        pallasCommArray.push(foreignPallas);
        cursor = newStart;
    }

    return [pallasCommArray, cursor];
}

/**
 * Returns `[evals, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function pointEvaluationsArrayFromFields(fields: FieldBn254[], length: number, offset: number): [PointEvaluations[], number] {
    let cursor = offset;
    let pallasCommArray = [];
    for (let i = 0; i < length; i++) {
        let [foreignPallas, newStart] = pointEvaluationsFromFields(fields, cursor);
        pallasCommArray.push(foreignPallas);
        cursor = newStart;
    }

    return [pallasCommArray, cursor];
}

// - Option deserialization functions

/**
 * If `fields[offset] == 0` returns `[undefined, offset]`.
 * Otherwise it returns `[evals, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of 
 * `PointEvaluations` in fields.
 */
export function optionalPointEvaluationsFromFields(fields: FieldBn254[], offset: number): [PointEvaluations | undefined, number] {
    let pointEvaluations = PointEvaluations.optionalFromFields(fields);
    let offsetWithFlag = offset + 1;

    return [pointEvaluations, offsetWithFlag + PointEvaluations.sizeInFields()];
}

// - Option array deserialization functions

export function optionalPointEvaluationsArrayFromFields(fields: FieldBn254[], length: number, offset: number): [PointEvaluations[] | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return pointEvaluationsArrayFromFields(fields, length, offsetWithFlag);
}
