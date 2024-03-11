import { Circuit, CircuitBn254, circuitMain, circuitMainBn254, publicBn254, public_ } from 'o1js';
import { ForeignPallas } from './foreign_fields/foreign_pallas.js';
import { ForeignScalar, ForeignScalarBn254 } from './foreign_fields/foreign_scalar.js';
import { OpeningProof } from './poly_commitment/commitment.js';

export class TestCircuit extends Circuit {
    @circuitMain
    static main(@public_ openingProof: OpeningProof) {
        let scalars = [ForeignScalar.from(0).assertAlmostReduced()];

        let randBase = ForeignScalar.from(1).assertAlmostReduced();
        let sgRandBase = ForeignScalar.from(1).assertAlmostReduced();
        let negRandBase = randBase.neg();

        scalars.push(
            negRandBase.mul(openingProof.z1).assertAlmostReduced()
                .sub(sgRandBase).assertAlmostReduced()
        );
    }
}

export class TestCircuitBn254 extends CircuitBn254 {
    @circuitMainBn254
    static main(@publicBn254 z1: ForeignScalarBn254) {
        let scalars = [ForeignScalarBn254.from(0).assertAlmostReduced()];

        // let randBase = ForeignScalarBn254.from(1).assertAlmostReduced();
        // let sgRandBase = ForeignScalarBn254.from(1).assertAlmostReduced();
        // let negRandBase = randBase.neg();

        scalars.push(
            z1.mul(z1.assertAlmostReduced()).assertAlmostReduced()
            // .sub(sgRandBase).assertAlmostReduced()
        );
    }
}
