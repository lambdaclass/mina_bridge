import { Circuit, circuitMain, public_ } from 'o1js';
import { ForeignPallas } from './foreign_fields/foreign_pallas.js';
import { ForeignScalar } from './foreign_fields/foreign_scalar.js';
import { OpeningProof } from './poly_commitment/commitment.js';

export class TestCircuit extends Circuit {
    // @circuitMain
    // static main(@public_ sg: ForeignPallas, @public_ z1: ForeignScalar) {
    //     let h = ForeignPallas.generator;
    //     let points = [h];
    //     let scalars = [ForeignScalar.from(0).assertAlmostReduced()];

    //     let randBase = ForeignScalar.from(1).assertAlmostReduced();
    //     let sgRandBase = ForeignScalar.from(1).assertAlmostReduced();
    //     let negRandBase = randBase.neg();

    //     points.push(sg);
    //     scalars.push(
    //         negRandBase.mul(z1).assertAlmostReduced()
    //             .sub(sgRandBase).assertAlmostReduced()
    //     );
    // }
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
