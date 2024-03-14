import { Polynomial } from "../src/polynomial.js";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar.js";

test("Evaluate polynomial", () => {
    const coef = [ForeignScalar.from(3), ForeignScalar.from(2), ForeignScalar.from(1)];
    const p = new Polynomial(coef);
    const x = ForeignScalar.from(4);

    let evaluation = p.evaluate(x);
    let expected = ForeignScalar.from(27);
    expect(evaluation.toBigInt().toString()).toEqual(expected.toBigInt().toString())
});
