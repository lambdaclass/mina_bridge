import { FieldBn254, ProvableBn254 } from "o1js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.js";
import { PolyComm } from "./poly_commitment/commitment.js";
import { LookupCommitments, PointEvaluations, ProofEvaluations, ProverCommitments } from "./prover/prover.js";
import { OpeningProof } from "./poly_commitment/opening_proof.js";

export abstract class FieldSerializable {
    static fromFields: (_fields: FieldBn254[]) => FieldSerializable;
    toFields: () => FieldBn254[];
}

// - Deserialization functions

//   - Item deserialization functions

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
 * Returns `[commitment, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PolyComm` 
 * in fields.
 */
export function lookupCommitmentsFromFields(fields: FieldBn254[], offset: number): [LookupCommitments, number] {
    let lookupCommitments = LookupCommitments.fromFields(fields);
    let newOffset = offset + lookupCommitmentsSizeInFields(lookupCommitments);

    return [lookupCommitments, newOffset];
}

/**
 * Returns `[evals, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `PointEvaluations` 
 * in fields.
 */
export function pointEvaluationsFromFields(fields: FieldBn254[], offset: number): [PointEvaluations, number] {
    let pointEvaluations = PointEvaluations.fromFields(fields);
    let newOffset = offset + pointEvaluationsSizeInFields(pointEvaluations);

    return [pointEvaluations, newOffset];
}

/**
 * Returns `[evals, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ProofEvaluations` 
 * in fields.
 */
export function proofEvaluationsFromFields(fields: FieldBn254[], offset: number): [ProofEvaluations, number] {
    let proofEvaluations = ProofEvaluations.fromFields(fields);
    let newOffset = offset + proofEvaluationsSizeInFields(proofEvaluations);

    return [proofEvaluations, newOffset];
}

/**
 * Returns `[commitments, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `ProverCommitments` 
 * in fields.
 */
export function proverCommitmentsFromFields(fields: FieldBn254[], offset: number): [ProverCommitments, number] {
    let proverCommitments = ProverCommitments.fromFields(fields);
    let newOffset = offset + proverCommitmentsSizeInFields(proverCommitments);

    return [proverCommitments, newOffset];
}

/**
 * Returns `[proof, newOffset]` where `newOffset` is `offset + length`, where `length` is the size of `OpeningProof` in fields.
 */
export function openingProofFromFields(fields: FieldBn254[], offset: number): [OpeningProof, number] {
    let openingProof = OpeningProof.fromFields(fields);
    let newOffset = offset + OpeningProof.sizeInFields();

    return [openingProof, newOffset];
}

//   - Array deserialization functions

export function arrayToFields(input: FieldSerializable[]) {
    return input.map((item) => item.toFields()).reduce((acc, fields) => acc.concat(fields), []);
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

//   - Option deserialization functions

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

//   - Option array deserialization functions

export function optionalScalarArrayFromFields(fields: FieldBn254[], offset: number): [ForeignScalar[] | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return scalarArrayFromFields(fields, offsetWithFlag);
}

export function optionalPointEvaluationsArrayFromFields(fields: FieldBn254[], length: number, offset: number): [PointEvaluations[] | undefined, number] {
    let offsetWithFlag = offset + 1;

    if (fields[offset].equals(0)) {
        return [undefined, offsetWithFlag];
    }

    return pointEvaluationsArrayFromFields(fields, length, offsetWithFlag);
}

// - Size functions

//   - Item size functions

function pallasCommSizeInFields(pallasComm: PolyComm<ForeignPallas>) {
    let unshiftedSize = 1 + pallasComm.unshifted.length * ForeignPallas.sizeInFields();
    // It adds 1 because we need to take into account the optional flag field
    let shiftedSize = 1 + (typeof pallasComm.shifted === "undefined" ? 0 : ForeignPallas.sizeInFields());

    return unshiftedSize + shiftedSize;
}

function lookupCommitmentsSizeInFields(lookupCommitments: LookupCommitments) {
    let sortedSize = pallasCommArraySizeInFields(lookupCommitments.sorted);
    let aggregSize = pallasCommSizeInFields(lookupCommitments.aggreg);
    // It adds 1 because we need to take into account the optional flag field
    let runtimeSize = 1 + (typeof lookupCommitments.runtime === "undefined" ? 0 : pallasCommSizeInFields(lookupCommitments.runtime));

    return sortedSize + aggregSize + runtimeSize;
}

function pointEvaluationsSizeInFields(pointEvaluations: PointEvaluations) {
    let zetaSize = ForeignScalar.sizeInFields();
    let zetaOmegaSize = ForeignScalar.sizeInFields();

    return zetaSize + zetaOmegaSize;
}

function proofEvaluationsSizeInFields(proofEvaluations: ProofEvaluations) {
    let wSize = pointEvaluationsArraySizeInFields(proofEvaluations.w);
    let zSize = pointEvaluationsSizeInFields(proofEvaluations.z);
    let sSize = pointEvaluationsSizeInFields(proofEvaluations.z);
    let coefficientsSize = pointEvaluationsArraySizeInFields(proofEvaluations.coefficients);
    let genericSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.genericSelector);
    let poseidonSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.poseidonSelector);
    let completeAddSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.completeAddSelector);
    let mulSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.mulSelector);
    let emulSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.emulSelector);
    let endomulScalarSelectorSize = pointEvaluationsSizeInFields(proofEvaluations.endomulScalarSelector);
    let publicInputSize = optionalPointEvaluationsSizeInFields(proofEvaluations.public_input);
    let rangeCheck0SelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.rangeCheck0Selector);
    let rangeCheck1SelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.rangeCheck1Selector);
    let foreignFieldAddSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.foreignFieldAddSelector);
    let foreignFieldMulSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.foreignFieldMulSelector);
    let xorSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.xorSelector);
    let rotSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.rotSelector);
    let lookupAggregationSize = optionalPointEvaluationsSizeInFields(proofEvaluations.lookupAggregation);
    let lookupTableSize = optionalPointEvaluationsSizeInFields(proofEvaluations.lookupTable);
    let lookupSortedSize = optionalPointEvaluationsArraySizeInFields(proofEvaluations.lookupSorted);
    let runtimeLookupTableSize = optionalPointEvaluationsSizeInFields(proofEvaluations.runtimeLookupTable);
    let runtimeLookupTableSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.runtimeLookupTableSelector);
    let xorLookupSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.xorLookupSelector);
    let lookupGateLookupSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.lookupGateLookupSelector);
    let rangeCheckLookupSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.rangeCheckLookupSelector);
    let foreignFieldMulLookupSelectorSize = optionalPointEvaluationsSizeInFields(proofEvaluations.foreignFieldMulLookupSelector);

    return wSize + zSize + sSize + coefficientsSize + genericSelectorSize + poseidonSelectorSize + completeAddSelectorSize +
        mulSelectorSize + emulSelectorSize + endomulScalarSelectorSize + publicInputSize + rangeCheck0SelectorSize +
        rangeCheck1SelectorSize + foreignFieldAddSelectorSize + foreignFieldMulSelectorSize + xorSelectorSize + rotSelectorSize +
        lookupAggregationSize + lookupTableSize + lookupSortedSize + runtimeLookupTableSize + runtimeLookupTableSelectorSize +
        xorLookupSelectorSize + lookupGateLookupSelectorSize + rangeCheckLookupSelectorSize + foreignFieldMulLookupSelectorSize;
}

function proverCommitmentsSizeInFields(proverCommitments: ProverCommitments) {
    let wCommSize = pallasCommArraySizeInFields(proverCommitments.wComm);
    let zCommSize = pallasCommSizeInFields(proverCommitments.zComm);
    let tCommSize = pallasCommSizeInFields(proverCommitments.tComm);
    let lookupSize = optionalLookupCommitmentsSizeInFields(proverCommitments.lookup);

    return wCommSize + zCommSize + tCommSize + lookupSize;
}

//   - Array size functions

function scalarArraySizeInFields(scalars: ForeignScalar[]) {
    let scalarsSize = scalars.length * ForeignScalar.sizeInFields();

    // `ForeignScalar array length field` + `ForeignScalar array`
    return 1 + scalarsSize;
}

function pallasCommArraySizeInFields(pallasComms: PolyComm<ForeignPallas>[]) {
    let pallasCommsSize = pallasComms.map((item) => pallasCommSizeInFields(item)).reduce((acc, size) => acc + size, 0);
    // `PolyComm array length field` + `PolyComm array`
    return 1 + pallasCommsSize;
}

function pointEvaluationsArraySizeInFields(pointEvaluations: PointEvaluations[]) {
    let pointEvaluationsSize = pointEvaluations.map((item) => pointEvaluationsSizeInFields(item)).reduce((acc, size) => acc + size, 0);
    // `PointEvaluations array length field` + `PointEvaluations array`
    return 1 + pointEvaluationsSize;
}

//   - Option size functions

function optionalPointEvaluationsSizeInFields(pointEvaluations?: PointEvaluations) {
    // It adds 1 because we need to take into account the optional flag field
    return 1 + (typeof pointEvaluations === "undefined" ? 0 : pointEvaluationsSizeInFields(pointEvaluations));
}

function optionalLookupCommitmentsSizeInFields(lookupCommitments?: LookupCommitments) {
    // It adds 1 because we need to take into account the optional flag field
    return 1 + (typeof lookupCommitments === "undefined" ? 0 : lookupCommitmentsSizeInFields(lookupCommitments));
}

//   - Option array size functions

function optionalPointEvaluationsArraySizeInFields(pointEvaluations?: PointEvaluations[]) {
    // It adds 1 because we need to take into account the optional flag field
    return 1 + (typeof pointEvaluations === "undefined" ? 0 : pointEvaluationsArraySizeInFields(pointEvaluations));
}
