import { bPoly, bPolyCoefficients } from "../src/poly_commitment/commitment";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";

test("bPoly", () => {
    const coeffs = [42, 25, 420].map((x) => ForeignScalar.from(x).assertAlmostReduced());
    const x = ForeignScalar.from(12);

    const res = bPoly(coeffs, x);
    const expected = ForeignScalar.from(0xE60E7F1C6C1);
    // expected value taken from verify_circuit_tests/

    expect(res.toBigInt().toString()).toEqual(expected.toBigInt().toString());
})

test("bPolyCoefficients", () => {
    const coeffs = [42, 25].map((x) => ForeignScalar.from(x).assertAlmostReduced());

    const res = bPolyCoefficients(coeffs)
        .map((s) => s.toBigInt().toString()).toString();
    const expected = [1, 25, 42, 1050].toString();
    // expected values taken from verify_circuit_tests/

    expect(res).toEqual(expected);
})
