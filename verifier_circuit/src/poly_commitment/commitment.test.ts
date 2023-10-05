import { Scalar } from "o1js"
import { bPoly, bPolyCoefficients } from "./commitment";

test("bPoly", () => {
    const coeffs = [42, 25, 420].map(Scalar.from);
    const x = Scalar.from(12);

    const res = bPoly(coeffs, x);
    const expected = Scalar.from(0xE60E7F1C6C1);
    // expected value taken from verify_circuit_tests/

    expect(res.toBigInt().toString()).toEqual(expected.toBigInt().toString());
})

test("bPolyCoefficients", () => {
    const coeffs = [42, 25].map(Scalar.from);

    const res = bPolyCoefficients(coeffs)
        .map((s) => s.toBigInt().toString()).toString();
    const expected = [1, 25, 42, 1050].toString();
    // expected values taken from verify_circuit_tests/

    expect(res).toEqual(expected);
})
