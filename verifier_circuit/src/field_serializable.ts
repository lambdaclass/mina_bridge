import { FieldBn254, ProvableBn254 } from "o1js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.js";
import { PolyComm } from "./poly_commitment/commitment.js";
import { LookupCommitments } from "./prover/prover.js";

export abstract class FieldSerializable {
    static fromFields: (_fields: FieldBn254[]) => FieldSerializable;
    toFields: () => FieldBn254[];
}

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
    let foreignPallas = ForeignPallas.fromFields(fields.slice(offset, newOffset)) as ForeignPallas;

    return [foreignPallas, newOffset];
}

/**
 * Returns `[commitment, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PolyComm` 
 * in fields.
 */
export function pallasCommFromFields(fields: FieldBn254[], offset: number): [PolyComm<ForeignPallas>, number] {
    let pallasComm = PolyComm.fromFields(fields);
    let newOffset = offset + pallasCommSizeInFields(pallasComm);

    return [pallasComm, newOffset];
}

/**
 * Returns `[commitment, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PolyComm` 
 * in fields.
 */
export function lookupCommFromFields(fields: FieldBn254[], offset: number): [LookupCommitments, number] {
    let lookupCommitments = LookupCommitments.fromFields(fields);
    let newOffset = offset + lookupCommitmentsSizeInFields(lookupCommitments);

    return [lookupCommitments, newOffset];
}

export function arrayToFields(input: FieldSerializable[]) {
    let inputLength = FieldBn254(input.length);
    let fields = input.map((item) => item.toFields()).reduce((acc, fields) => acc.concat(fields), []);

    return [inputLength, ...fields];
}

/**
 * Returns `[scalars, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function scalarArrayFromFields(fields: FieldBn254[], offset: number): [ForeignScalar[], number] {
    let fieldsLength = 0;
    ProvableBn254.asProver(() => {
        fieldsLength = Number(fields[offset].toBigInt());
    });
    let offsetWithLength = offset + 1;
    let cursor = offsetWithLength;
    let foreignScalarArray = [];
    for (let i = 0; i < fieldsLength; i++) {
        let [foreignScalar, newStart] = scalarFromFields(fields, cursor);
        foreignScalarArray.push(foreignScalar);
        cursor = newStart;
    }

    return [foreignScalarArray, cursor];
}

/**
 * Returns `[points, newOffset]` where `newOffset` is `offset + length`, where `length` is the length of the field array 
 * used for deserializing.
 */
export function pallasArrayFromFields(fields: FieldBn254[], offset: number): [ForeignPallas[], number] {
    let fieldsLength = 0;
    ProvableBn254.asProver(() => {
        fieldsLength = Number(fields[offset].toBigInt());
    });
    let offsetWithLength = offset + 1;
    let cursor = offsetWithLength;
    let foreignPallasArray = [];
    for (let i = 0; i < fieldsLength; i++) {
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
export function pallasCommArrayFromFields(fields: FieldBn254[], offset: number): [PolyComm<ForeignPallas>[], number] {
    let fieldsLength = 0;
    ProvableBn254.asProver(() => {
        fieldsLength = Number(fields[offset].toBigInt());
    });
    let offsetWithLength = offset + 1;
    let cursor = offsetWithLength;
    let pallasCommArray = [];
    for (let i = 0; i < fieldsLength; i++) {
        let [foreignPallas, newStart] = pallasCommFromFields(fields, cursor);
        pallasCommArray.push(foreignPallas);
        cursor = newStart;
    }

    return [pallasCommArray, cursor];
}

export function optionalToFields(input?: FieldSerializable) {
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
export function optionalScalarFromFields(fields: FieldBn254[], offset: number): [ForeignScalar | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return scalarFromFields(fields, offsetWithFlag);
}


/**
 * If `fields[offset] == 0` returns `[undefined, offset]`.
 * Otherwise it returns `[scalar, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of 
 * `ForeignPallas` in fields.
 */
export function optionalPallasFromFields(fields: FieldBn254[], offset: number): [ForeignPallas | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return pallasFromFields(fields, offsetWithFlag);
}

export function optionalArrayToFields(input?: FieldSerializable[]) {
    if (typeof input === "undefined") {
        return [FieldBn254(0)];
    }

    let fields = arrayToFields(input);

    return [FieldBn254(1), ...fields];
}

export function optionalScalarArrayFromFields(fields: FieldBn254[], offset: number): [ForeignScalar[] | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return scalarArrayFromFields(fields, offsetWithFlag);
}

function pallasCommSizeInFields(pallasComm: PolyComm<ForeignPallas>) {
    let unshiftedSize = 1 + pallasComm.unshifted.length * ForeignPallas.sizeInFields();
    let shiftedSize = 1 + (typeof pallasComm.shifted === "undefined" ? 0 : ForeignPallas.sizeInFields());

    return unshiftedSize + shiftedSize;
}

function pallasCommArraySizeInFields(pallasComms: PolyComm<ForeignPallas>[]) {
    let pallasCommsSize = pallasComms.map((item) => pallasCommSizeInFields(item)).reduce((acc, size) => acc + size, 0);
    // `PolyComm array length field` + `PolyComm array`
    return 1 + pallasCommsSize;
}

function lookupCommitmentsSizeInFields(lookupCommitments: LookupCommitments) {
    let sortedSize = pallasCommArraySizeInFields(lookupCommitments.sorted);
    let aggregSize = pallasCommSizeInFields(lookupCommitments.aggreg);
    let runtimeSize = 1 + (typeof lookupCommitments.runtime === "undefined" ? 0 : pallasCommSizeInFields(lookupCommitments.runtime));

    // It adds 1 because we need to take into account the optional flag field
    return sortedSize + aggregSize + runtimeSize;
}
