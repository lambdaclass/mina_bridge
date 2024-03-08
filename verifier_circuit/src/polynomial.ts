import { ForeignScalar } from "./foreign_fields/foreign_scalar.js"

export class Polynomial {
    coef: Array<ForeignScalar>

    constructor(coef: Array<ForeignScalar>) {
        this.coef = coef
    }

    evaluate(x: ForeignScalar): ForeignScalar {
        let result = ForeignScalar.from(0).assertAlmostReduced();
        for (let i = 0; i < this.coef.length; i++) {
            result = result.mul(x).add(this.coef[i]).assertAlmostReduced();
        }
        return result
    }

    static buildAndEvaluate(coeffs: ForeignScalar[], x: ForeignScalar): ForeignScalar {
        const poly = new Polynomial(coeffs);
        return poly.evaluate(x);
    }
}
