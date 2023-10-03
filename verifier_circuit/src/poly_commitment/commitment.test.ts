import { Scalar } from "o1js"
import { bPoly, bPolyCoefficients } from "./commitment";

test("bPoly", () => {
    const coeffs = [42, 25, 420].map(Scalar.from);
    const x = Scalar.from(10);

    const res = bPoly(coeffs, x);
    const expected = Scalar.from(15809371031233);
    // expected value taken from verify_circuit_tests/

    expect(res).toEqual(expected);
})

test("bPolyCoefficients", () => {
    const coeffs = [42, 25].map(Scalar.from);

    const res = bPolyCoefficients(coeffs);
    const expected = [1, 19, 42];
    // expected values taken from verify_circuit_tests/

    expect(res).toEqual(expected);
})
