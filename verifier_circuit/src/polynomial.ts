import { Scalar } from "o1js"
import { ForeignScalar } from "./foreign_fields/foreign_scalar"

export class Polynomial {
    coef: Array<ForeignScalar>

    constructor(coef: Array<ForeignScalar>) {
        this.coef = coef
    }

    evaluate(x: ForeignScalar): ForeignScalar {
        let result = ForeignScalar.from(0)
        for (let i = 0; i < this.coef.length; i++) {
            result = result.mul(x).add(this.coef[i])
        }
        return result
    }

    static buildAndEvaluate(coeffs: ForeignScalar[], x: ForeignScalar): ForeignScalar {
        const poly = new Polynomial(coeffs);
        return poly.evaluate(x);
    }
}
