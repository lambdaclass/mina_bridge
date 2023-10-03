import { Scalar } from "o1js";
import { invScalar, powScalar } from "./scalar";

test("powScalar", () => {
    const n = Scalar.from(42);
    const exp = 5;
    const res = Scalar.from(130691232); // from python

    expect(powScalar(n, exp)).toEqual(res);
})


test("invScalar", () => {
    // Create random Scalar
    const rand_base = Scalar.from(Math.floor(Math.random() * 16));
    const rand_exp = Math.floor(Math.random() * 32);
    const n = powScalar(rand_base, rand_exp);

    expect(n.mul(invScalar(n))).toEqual(Scalar.from(1));
})
