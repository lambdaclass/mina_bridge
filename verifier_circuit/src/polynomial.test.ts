import { Field, Scalar } from "o1js";
import { Polynomial } from "./polynomial.js";

test("Evaluate polynomial", () => {
    const coef = [Scalar.from(1), Scalar.from(2), Scalar.from(3)];
    const p = new Polynomial(coef);
    const x = Scalar.from(4);

    let evaluation = p.evaluate(x);
    let expected = Scalar.from(27);
    expect(expected).toEqual(evaluation);
});
