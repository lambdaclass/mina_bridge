import { CircuitBn254, circuitMainBn254, publicBn254 } from 'o1js';
import { ForeignScalar } from './foreign_fields/foreign_scalar.js';
import { OpeningProof } from './poly_commitment/opening_proof.js';

export class TestCircuit extends CircuitBn254 {
    @circuitMainBn254
    static main(@publicBn254 openingProof: OpeningProof) {
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
