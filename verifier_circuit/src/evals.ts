import { FieldBn254, ProvableBn254 } from "o1js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.js";

export abstract class Evals {
    static fromFields: (_fields: FieldBn254[]) => Evals;
    toFields: () => FieldBn254[];
}

/**
 * Returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ForeignScalar` 
 * in fields.
 */
export function foreignScalarFromFields(fields: FieldBn254[], offset: number): [ForeignScalar, number] {
    let newOffset = offset + ForeignScalar.sizeInFields();
    let foreignScalar = ForeignScalar.fromFields(fields.slice(offset, newOffset));

    return [foreignScalar, newOffset]
}

/**
 * Returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ForeignPallas` 
 * in fields.
 */
export function foreignPallasFromFields(fields: FieldBn254[], offset: number): [ForeignPallas, number] {
    let newOffset = offset + ForeignPallas.sizeInFields();
    let foreignPallas = ForeignPallas.fromFields(fields.slice(offset, newOffset)) as ForeignPallas;

    return [foreignPallas, newOffset]
}

export function evalsArrayToFields(input: Evals[]) {
    let inputLength = FieldBn254(input.length);
    let fields = input.map((item) => item.toFields()).reduce((acc, fields) => acc.concat(fields));

    return [inputLength, ...fields];
}

/**
 * Returns `[scalars, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function foreignScalarArrayFromFields(fields: FieldBn254[], offset: number): [ForeignScalar[], number] {
    let fieldsLength = 0;
    ProvableBn254.asProver(() => {
        fieldsLength = Number(fields[offset].toBigInt());
    });
    let offsetWithLength = offset + 1;
    let foreignScalarArray = [];
    for (let i = 0; i < fieldsLength; i++) {
        let start = offsetWithLength + ForeignScalar.sizeInFields() * i;
        let end = start + ForeignScalar.sizeInFields();
        foreignScalarArray.push(ForeignScalar.fromFields(fields.slice(start, end)));
    }

    return [foreignScalarArray, offsetWithLength + fieldsLength * ForeignScalar.sizeInFields()];
}

/**
 * Returns `[scalars, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function foreignPallasArrayFromFields(fields: FieldBn254[], offset: number): [ForeignPallas[], number] {
    let fieldsLength = 0;
    ProvableBn254.asProver(() => {
        fieldsLength = Number(fields[offset].toBigInt());
    });
    let offsetWithLength = offset + 1;
    let foreignPallasArray = [];
    for (let i = 0; i < fieldsLength; i++) {
        let start = offsetWithLength + ForeignPallas.sizeInFields() * i;
        let end = start + ForeignPallas.sizeInFields();
        foreignPallasArray.push(ForeignPallas.fromFields(fields.slice(start, end)) as ForeignPallas);
    }

    return [foreignPallasArray, offsetWithLength + fieldsLength * ForeignPallas.sizeInFields()];
}

export function optionalEvalsToFields(input?: Evals) {
    if (typeof input === "undefined") {
        return [FieldBn254(0)];
    }

    let fields = input?.toFields();

    return [FieldBn254(1), ...fields];
}

/**
 * If `fields[offset] == 0` returns `[undefined, offset]`.
 * Otherwise it returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of 
 * `ForeignScalar` in fields.
 */
export function optionalForeignScalarFromFields(fields: FieldBn254[], offset: number): [ForeignScalar | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return foreignScalarFromFields(fields, offsetWithFlag);
}


/**
 * If `fields[offset] == 0` returns `[undefined, offset]`.
 * Otherwise it returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of 
 * `ForeignPallas` in fields.
 */
export function optionalForeignPallasFromFields(fields: FieldBn254[], offset: number): [ForeignPallas | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return foreignPallasFromFields(fields, offsetWithFlag);
}

export function optionalEvalsArrayToFields(input?: Evals[]) {
    if (typeof input === "undefined") {
        return [FieldBn254(0)];
    }

    let fields = evalsArrayToFields(input);

    return [FieldBn254(1), ...fields];
}

export function optionalForeignScalarArrayFromFields(fields: FieldBn254[], offset: number): [ForeignScalar[] | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return foreignScalarArrayFromFields(fields, offsetWithFlag);
}
