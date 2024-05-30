import { CircuitBn254, circuitMainBn254, FieldBn254, publicBn254 } from 'o1js';
import { ForeignScalar } from './foreign_fields/foreign_scalar.ts';
import { OpeningProof } from './poly_commitment/opening_proof.ts';

export class TestCircuit extends CircuitBn254 {
    @circuitMainBn254
    static main(@publicBn254 openingProof: OpeningProof) {
        let scalars = [ForeignScalar.from(0).assertAlmostReduced()];

        let randBase = ForeignScalar.from(1).assertAlmostReduced();
        let sgRandBase = ForeignScalar.from(1).assertAlmostReduced();
        let negRandBase = randBase.neg();

        const scalar = negRandBase
            .add(openingProof.z1).assertAlmostReduced()
            .sub(sgRandBase).assertAlmostReduced();

        scalars.push(scalar);
    }
}

export class MyScalar {
    scalar: ForeignScalar;

    constructor(scalar: ForeignScalar) {
        this.scalar = scalar;
    }

    static sizeInFields() {
        return ForeignScalar.sizeInFields();
    }

    static fromFields(fields: FieldBn254[]) {
        return new MyScalar(ForeignScalar.fromFields(fields));
    }

    toFields() {
        return ForeignScalar.toFields(this.scalar);
    }

    static toFields(myscalar: MyScalar) {
        return myscalar.toFields();
    }
}

export class ScalarAddCircuit extends CircuitBn254 {
    @circuitMainBn254
    static main(@publicBn254 myscalar: MyScalar) {
        let scalars = [ForeignScalar.from(0).assertAlmostReduced()];

        let randBase = ForeignScalar.from(1).assertAlmostReduced();
        let sgRandBase = ForeignScalar.from(1).assertAlmostReduced();
        let negRandBase = randBase.neg();

        const scalarr = negRandBase
            .add(myscalar.scalar).assertAlmostReduced()
            .sub(sgRandBase).assertAlmostReduced();

        scalars.push(scalarr);
    }
}
