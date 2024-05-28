import { FieldBn254 } from "o1js";
import { GateType } from "../circuits/gate.js";
import { pointEvaluationsArrayFromFields, pointEvaluationsFromFields, optionalPointEvaluationsFromFields, optionalPointEvaluationsArrayFromFields, arrayToFields } from "../field_serializable.js";
import { LookupPattern } from "../lookups/lookups.js";
import { Polynomial } from "../polynomial.js";
import { Column } from "./expr.js";
import { PointEvaluations } from "./point_evaluations.js";

/**
 * Polynomial evaluations contained in a `ProverProof`.
 * **Chunked evaluations** `Field` is instantiated with vectors with a length that equals the length of the chunk
 * **Non chunked evaluations** `Field` is instantiated with a field, so they are single-sized#[serde_as]
 */
export class ProofEvaluations {
    /* public input polynomials */
    public_input?: PointEvaluations
    /* witness polynomials */
    w: Array<PointEvaluations> // of size 15, total num of registers (columns)
    /* permutation polynomial */
    z: PointEvaluations
    /*
     * permutation polynomials
     * (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
     */
    s: Array<PointEvaluations> // of size 7 - 1, total num of wirable registers minus one
    /* coefficient polynomials */
    coefficients: Array<PointEvaluations> // of size 15, total num of registers (columns)
    /* evaluation of the generic selector polynomial */
    genericSelector: PointEvaluations
    /* evaluation of the poseidon selector polynomial */
    poseidonSelector: PointEvaluations
    /** evaluation of the elliptic curve addition selector polynomial */
    completeAddSelector: PointEvaluations
    /** evaluation of the elliptic curve variable base scalar multiplication selector polynomial */
    mulSelector: PointEvaluations
    /** evaluation of the endoscalar multiplication selector polynomial */
    emulSelector: PointEvaluations
    /** evaluation of the endoscalar multiplication scalar computation selector polynomial */
    endomulScalarSelector: PointEvaluations

    // Optional gates
    /** evaluation of the RangeCheck0 selector polynomial **/
    rangeCheck0Selector?: PointEvaluations
    /** evaluation of the RangeCheck1 selector polynomial **/
    rangeCheck1Selector?: PointEvaluations
    /** evaluation of the ForeignFieldAdd selector polynomial **/
    foreignFieldAddSelector?: PointEvaluations
    /** evaluation of the ForeignFieldMul selector polynomial **/
    foreignFieldMulSelector?: PointEvaluations
    /** evaluation of the Xor selector polynomial **/
    xorSelector?: PointEvaluations
    /** evaluation of the Rot selector polynomial **/
    rotSelector?: PointEvaluations

    // lookup-related evaluations
    /** evaluation of lookup aggregation polynomial **/
    lookupAggregation?: PointEvaluations
    /** evaluation of lookup table polynomial **/
    lookupTable?: PointEvaluations
    /** evaluation of lookup sorted polynomials **/
    lookupSorted?: PointEvaluations[] // fixed size of 5
    /** evaluation of runtime lookup table polynomial **/
    runtimeLookupTable?: PointEvaluations

    // lookup selectors
    /** evaluation of the runtime lookup table selector polynomial **/
    runtimeLookupTableSelector?: PointEvaluations
    /** evaluation of the Xor range check pattern selector polynomial **/
    xorLookupSelector?: PointEvaluations
    /** evaluation of the Lookup range check pattern selector polynomial **/
    lookupGateLookupSelector?: PointEvaluations
    /** evaluation of the RangeCheck range check pattern selector polynomial **/
    rangeCheckLookupSelector?: PointEvaluations
    /** evaluation of the ForeignFieldMul range check pattern selector polynomial **/
    foreignFieldMulLookupSelector?: PointEvaluations

    constructor(
        w: Array<PointEvaluations>,
        z: PointEvaluations,
        s: Array<PointEvaluations>,
        coefficients: Array<PointEvaluations>,
        genericSelector: PointEvaluations,
        poseidonSelector: PointEvaluations,
        completeAddSelector: PointEvaluations,
        mulSelector: PointEvaluations,
        emulSelector: PointEvaluations,
        endomulScalarSelector: PointEvaluations,
        public_input?: PointEvaluations,
        rangeCheck0Selector?: PointEvaluations,
        rangeCheck1Selector?: PointEvaluations,
        foreignFieldAddSelector?: PointEvaluations,
        foreignFieldMulSelector?: PointEvaluations,
        xorSelector?: PointEvaluations,
        rotSelector?: PointEvaluations,
        lookupAggregation?: PointEvaluations,
        lookupTable?: PointEvaluations,
        lookupSorted?: PointEvaluations[], // fixed size of 5
        runtimeLookupTable?: PointEvaluations,
        runtimeLookupTableSelector?: PointEvaluations,
        xorLookupSelector?: PointEvaluations,
        lookupGateLookupSelector?: PointEvaluations,
        rangeCheckLookupSelector?: PointEvaluations,
        foreignFieldMulLookupSelector?: PointEvaluations,
    ) {
        this.w = w;
        this.z = z;
        this.s = s;
        this.coefficients = coefficients;
        this.genericSelector = genericSelector;
        this.poseidonSelector = poseidonSelector;
        this.completeAddSelector = completeAddSelector;
        this.mulSelector = mulSelector;
        this.emulSelector = emulSelector;
        this.endomulScalarSelector = endomulScalarSelector;
        this.public_input = public_input;
        this.rangeCheck0Selector = rangeCheck0Selector;
        this.rangeCheck1Selector = rangeCheck1Selector;
        this.foreignFieldAddSelector = foreignFieldAddSelector;
        this.foreignFieldMulSelector = foreignFieldMulSelector;
        this.xorSelector = xorSelector;
        this.rotSelector = rotSelector;
        this.lookupAggregation = lookupAggregation;
        this.lookupTable = lookupTable;
        this.lookupSorted = lookupSorted;
        this.runtimeLookupTable = runtimeLookupTable;
        this.runtimeLookupTableSelector = runtimeLookupTableSelector;
        this.xorLookupSelector = xorLookupSelector;
        this.lookupGateLookupSelector = lookupGateLookupSelector;
        this.rangeCheckLookupSelector = rangeCheckLookupSelector;
        this.foreignFieldMulLookupSelector = foreignFieldMulLookupSelector;
        return this;
    }

    map(f: (e: PointEvaluations) => PointEvaluations): ProofEvaluations {
        let {
            w,
            z,
            s,
            coefficients,
            genericSelector,
            poseidonSelector,
            completeAddSelector,
            mulSelector,
            emulSelector,
            endomulScalarSelector,
            rangeCheck0Selector,
            rangeCheck1Selector,
            foreignFieldAddSelector,
            foreignFieldMulSelector,
            xorSelector,
            rotSelector,
            lookupAggregation,
            lookupTable,
            lookupSorted, // fixed size of 5
            runtimeLookupTable,
            runtimeLookupTableSelector,
            xorLookupSelector,
            lookupGateLookupSelector,
            rangeCheckLookupSelector,
            foreignFieldMulLookupSelector,
        } = this;

        let public_input = undefined;
        if (this.public_input) public_input = f(this.public_input);

        const optional_f = (e?: PointEvaluations) => e ? f(e) : undefined;

        return new ProofEvaluations(
            w.map(f),
            f(z),
            s.map(f),
            coefficients.map(f),
            f(genericSelector),
            f(poseidonSelector),
            f(completeAddSelector),
            f(mulSelector),
            f(emulSelector),
            f(endomulScalarSelector),
            public_input,
            optional_f(rangeCheck0Selector),
            optional_f(rangeCheck1Selector),
            optional_f(foreignFieldAddSelector),
            optional_f(foreignFieldMulSelector),
            optional_f(xorSelector),
            optional_f(rotSelector),
            optional_f(lookupAggregation),
            optional_f(lookupTable),
            lookupSorted ? lookupSorted!.map(f) : undefined, // fixed size of 5
            optional_f(runtimeLookupTable),
            optional_f(runtimeLookupTableSelector),
            optional_f(xorLookupSelector),
            optional_f(lookupGateLookupSelector),
            optional_f(rangeCheckLookupSelector),
            optional_f(foreignFieldMulLookupSelector),
        )
    }

    /*
    Returns a new PointEvaluations struct with the combined evaluations.
    */
    static combine(
        evals: ProofEvaluations,
        pt: PointEvaluations
    ): ProofEvaluations {
        return evals.map((orig) => new PointEvaluations(
            Polynomial.buildAndEvaluate([orig.zeta], pt.zeta),
            Polynomial.buildAndEvaluate([orig.zetaOmega], pt.zetaOmega)
        ));
    }

    getColumn(col: Column): PointEvaluations | undefined {
        switch (col.kind) {
            case "witness": {
                return this.w[col.index];
            }
            case "z": {
                return this.z;
            }
            case "lookupsorted": {
                return this.lookupSorted?.[col.index];
            }
            case "lookupaggreg": {
                return this.lookupAggregation;
            }
            case "lookuptable": {
                return this.lookupTable;
            }
            case "lookupkindindex": {
                if (col.pattern === LookupPattern.Xor) return this.xorLookupSelector;
                if (col.pattern === LookupPattern.Lookup) return this.lookupGateLookupSelector;
                if (col.pattern === LookupPattern.RangeCheck) return this.rangeCheckLookupSelector;
                if (col.pattern === LookupPattern.ForeignFieldMul) return this.foreignFieldMulLookupSelector;
                else return undefined
            }
            case "lookupruntimeselector": {
                return this.runtimeLookupTableSelector;
            }
            case "lookupruntimetable": {
                return this.runtimeLookupTable;
            }
            case "index": {
                if (col.typ === GateType.Generic) return this.genericSelector;
                if (col.typ === GateType.Poseidon) return this.poseidonSelector;
                if (col.typ === GateType.CompleteAdd) return this.completeAddSelector;
                if (col.typ === GateType.VarBaseMul) return this.mulSelector;
                if (col.typ === GateType.EndoMul) return this.emulSelector;
                if (col.typ === GateType.EndoMulScalar) return this.endomulScalarSelector;
                if (col.typ === GateType.RangeCheck0) return this.rangeCheck0Selector;
                if (col.typ === GateType.RangeCheck1) return this.rangeCheck1Selector;
                if (col.typ === GateType.ForeignFieldAdd) return this.foreignFieldAddSelector;
                if (col.typ === GateType.ForeignFieldMul) return this.foreignFieldMulSelector;
                if (col.typ === GateType.Xor16) return this.xorSelector;
                if (col.typ === GateType.Rot64) return this.rotSelector;
                else return undefined;
            }
            case "coefficient": {
                return this.coefficients[col.index];
            }
            case "permutation": {
                return this.s[col.index];
            }
        }
    }

    static #wLength() {
        return 15;
    }

    static #sLength() {
        return 6;
    }

    static #coefficientsLength() {
        return 15;
    }

    static fromFields(fields: FieldBn254[]): ProofEvaluations {
        let [w, zOffset] = pointEvaluationsArrayFromFields(fields, this.#wLength(), 0);
        let [z, sOffset] = pointEvaluationsFromFields(fields, zOffset);
        let [s, coefficientsOffset] = pointEvaluationsArrayFromFields(fields, this.#sLength(), sOffset);
        let [coefficients, genericSelectorOffset] = pointEvaluationsArrayFromFields(fields, this.#coefficientsLength(), coefficientsOffset);
        let [genericSelector, poseidonSelectorOffset] = pointEvaluationsFromFields(fields, genericSelectorOffset);
        let [poseidonSelector, completeAddSelectorOffset] = pointEvaluationsFromFields(fields, poseidonSelectorOffset);
        let [completeAddSelector, mulSelectorOffset] = pointEvaluationsFromFields(fields, completeAddSelectorOffset);
        let [mulSelector, emulSelectorOffset] = pointEvaluationsFromFields(fields, mulSelectorOffset);
        let [emulSelector, endomulScalarSelectorOffset] = pointEvaluationsFromFields(fields, emulSelectorOffset);
        let [endomulScalarSelector, publicInputOffset] = pointEvaluationsFromFields(fields, endomulScalarSelectorOffset);
        let [public_input, rangeCheck0SelectorOffset] = optionalPointEvaluationsFromFields(fields, publicInputOffset);
        let [rangeCheck0Selector, rangeCheck1SelectorOffset] = optionalPointEvaluationsFromFields(fields, rangeCheck0SelectorOffset);
        let [rangeCheck1Selector, foreignFieldAddSelectorOffset] = optionalPointEvaluationsFromFields(fields, rangeCheck1SelectorOffset);
        let [foreignFieldAddSelector, foreignFieldMulSelectorOffset] = optionalPointEvaluationsFromFields(fields, foreignFieldAddSelectorOffset);
        let [foreignFieldMulSelector, xorSelectorOffset] = optionalPointEvaluationsFromFields(fields, foreignFieldMulSelectorOffset);
        let [xorSelector, rotSelectorOffset] = optionalPointEvaluationsFromFields(fields, xorSelectorOffset);
        let [rotSelector, lookupAggregationOffset] = optionalPointEvaluationsFromFields(fields, rotSelectorOffset);
        let [lookupAggregation, lookupTableOffset] = optionalPointEvaluationsFromFields(fields, lookupAggregationOffset);
        let [lookupTable, lookupSortedOffset] = optionalPointEvaluationsFromFields(fields, lookupTableOffset);
        // TODO: Check `lookupSorted` length
        let [lookupSorted, runtimeLookupTableOffset] = optionalPointEvaluationsArrayFromFields(fields, 0, lookupSortedOffset);
        let [runtimeLookupTable, runtimeLookupTableSelectorOffset] = optionalPointEvaluationsFromFields(fields, runtimeLookupTableOffset);
        let [runtimeLookupTableSelector, xorLookupSelectorOffset] = optionalPointEvaluationsFromFields(fields, runtimeLookupTableSelectorOffset);
        let [xorLookupSelector, lookupGateLookupSelectorOffset] = optionalPointEvaluationsFromFields(fields, xorLookupSelectorOffset);
        let [lookupGateLookupSelector, rangeCheckLookupSelectorOffset] = optionalPointEvaluationsFromFields(fields, lookupGateLookupSelectorOffset);
        let [rangeCheckLookupSelector, foreignFieldMulLookupSelectorOffset] = optionalPointEvaluationsFromFields(fields, rangeCheckLookupSelectorOffset);
        let [foreignFieldMulLookupSelector, _] = optionalPointEvaluationsFromFields(fields, foreignFieldMulLookupSelectorOffset);

        return new ProofEvaluations(
            w,
            z,
            s,
            coefficients,
            genericSelector,
            poseidonSelector,
            completeAddSelector,
            mulSelector,
            emulSelector,
            endomulScalarSelector,
            public_input,
            rangeCheck0Selector,
            rangeCheck1Selector,
            foreignFieldAddSelector,
            foreignFieldMulSelector,
            xorSelector,
            rotSelector,
            lookupAggregation,
            lookupTable,
            lookupSorted,
            runtimeLookupTable,
            runtimeLookupTableSelector,
            xorLookupSelector,
            lookupGateLookupSelector,
            rangeCheckLookupSelector,
            foreignFieldMulLookupSelector
        );
    }

    toFields() {
        let w = arrayToFields(this.w);
        let z = this.z.toFields();
        let s = arrayToFields(this.s);
        let coefficients = arrayToFields(this.coefficients);
        let genericSelector = this.genericSelector.toFields();
        let poseidonSelector = this.poseidonSelector.toFields();
        let completeAddSelector = this.completeAddSelector.toFields();
        let mulSelector = this.mulSelector.toFields();
        let emulSelector = this.emulSelector.toFields();
        let endomulScalarSelector = this.endomulScalarSelector.toFields();
        let public_input = PointEvaluations.optionalToFields(this.public_input);
        let rangeCheck0Selector = PointEvaluations.optionalToFields(this.rangeCheck0Selector);
        let rangeCheck1Selector = PointEvaluations.optionalToFields(this.rangeCheck1Selector);
        let foreignFieldAddSelector = PointEvaluations.optionalToFields(this.foreignFieldAddSelector);
        let foreignFieldMulSelector = PointEvaluations.optionalToFields(this.foreignFieldMulSelector);
        let xorSelector = PointEvaluations.optionalToFields(this.xorSelector);
        let rotSelector = PointEvaluations.optionalToFields(this.rotSelector);
        let lookupAggregation = PointEvaluations.optionalToFields(this.lookupAggregation);
        let lookupTable = PointEvaluations.optionalToFields(this.lookupTable);
        // TODO: Check `lookupSorted` length
        let lookupSorted = PointEvaluations.optionalArrayToFields(0, this.lookupSorted);
        let runtimeLookupTable = PointEvaluations.optionalToFields(this.runtimeLookupTable);
        let runtimeLookupTableSelector = PointEvaluations.optionalToFields(this.runtimeLookupTableSelector);
        let xorLookupSelector = PointEvaluations.optionalToFields(this.xorLookupSelector);
        let lookupGateLookupSelector = PointEvaluations.optionalToFields(this.lookupGateLookupSelector);
        let rangeCheckLookupSelector = PointEvaluations.optionalToFields(this.rangeCheckLookupSelector);
        let foreignFieldMulLookupSelector = PointEvaluations.optionalToFields(this.foreignFieldMulLookupSelector);

        return [
            ...w,
            ...z,
            ...s,
            ...coefficients,
            ...genericSelector,
            ...poseidonSelector,
            ...completeAddSelector,
            ...mulSelector,
            ...emulSelector,
            ...endomulScalarSelector,
            ...public_input,
            ...rangeCheck0Selector,
            ...rangeCheck1Selector,
            ...foreignFieldAddSelector,
            ...foreignFieldMulSelector,
            ...xorSelector,
            ...rotSelector,
            ...lookupAggregation,
            ...lookupTable,
            ...lookupSorted,
            ...runtimeLookupTable,
            ...runtimeLookupTableSelector,
            ...xorLookupSelector,
            ...lookupGateLookupSelector,
            ...rangeCheckLookupSelector,
            ...foreignFieldMulLookupSelector
        ];
    }

    static sizeInFields() {
        const wSize = this.#wLength() * PointEvaluations.sizeInFields();
        const zSize = PointEvaluations.sizeInFields();
        const sSize = this.#sLength() * PointEvaluations.sizeInFields();
        const coefficientsSize = this.#coefficientsLength() * PointEvaluations.sizeInFields();
        const genericSelectorSize = PointEvaluations.sizeInFields();
        const poseidonSelectorSize = PointEvaluations.sizeInFields();
        const completeAddSelectorSize = PointEvaluations.sizeInFields();
        const mulSelectorSize = PointEvaluations.sizeInFields();
        const emulSelectorSize = PointEvaluations.sizeInFields();
        const endomulScalarSelectorSize = PointEvaluations.sizeInFields();
        const publicInputSize = 1 + PointEvaluations.sizeInFields();
        // TODO: Check the proof fields size defined above with a proof that has non-null values
        const rangeCheck0SelectorSize = 1 + PointEvaluations.sizeInFields();
        const rangeCheck1SelectorSize = 1 + PointEvaluations.sizeInFields();
        const foreignFieldAddSelectorSize = 1 + PointEvaluations.sizeInFields();
        const foreignFieldMulSelectorSize = 1 + PointEvaluations.sizeInFields();
        const xorSelectorSize = 1 + PointEvaluations.sizeInFields();
        const rotSelectorSize = 1 + PointEvaluations.sizeInFields();
        const lookupAggregationSize = 1 + PointEvaluations.sizeInFields();
        const lookupTableSize = 1 + PointEvaluations.sizeInFields();
        // TODO: Check `lookupSorted` length
        const lookupSortedSize = 1;
        const runtimeLookupTableSize = 1 + PointEvaluations.sizeInFields();
        const runtimeLookupTableSelectorSize = 1 + PointEvaluations.sizeInFields();
        const xorLookupSelectorSize = 1 + PointEvaluations.sizeInFields();
        const lookupGateLookupSelectorSize = 1 + PointEvaluations.sizeInFields();
        const rangeCheckLookupSelectorSize = 1 + PointEvaluations.sizeInFields();
        const foreignFieldMulLookupSelectorSize = 1 + PointEvaluations.sizeInFields();

        return wSize + zSize + sSize + coefficientsSize + genericSelectorSize + poseidonSelectorSize +
            completeAddSelectorSize + mulSelectorSize + emulSelectorSize + endomulScalarSelectorSize + publicInputSize +
            rangeCheck0SelectorSize + rangeCheck1SelectorSize + foreignFieldAddSelectorSize + foreignFieldMulSelectorSize +
            xorSelectorSize + rotSelectorSize + lookupAggregationSize + lookupTableSize + lookupSortedSize +
            runtimeLookupTableSize + runtimeLookupTableSelectorSize + xorLookupSelectorSize + lookupGateLookupSelectorSize +
            rangeCheckLookupSelectorSize + foreignFieldMulLookupSelectorSize;
    }
}
