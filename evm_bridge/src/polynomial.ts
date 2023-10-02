import { Scalar } from "o1js"

export class Polynomial {
    coef: Array<Scalar>

    constructor(coef: Array<Scalar>) {
        this.coef = coef
    }

    evaluate(x: Scalar): Scalar {
        let result = Scalar.from(0)
        for (let i = 0; i < this.coef.length; i++) {
            result = result.mul(x).add(this.coef[i])
        }
        return result
    }

    static buildAndEvaluate(coeffs: Scalar[], x: Scalar): Scalar {
        const poly = new Polynomial(coeffs);
        return poly.evaluate(x);
    }
}
