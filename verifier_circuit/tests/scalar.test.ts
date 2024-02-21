import { Scalar } from "o1js";
import { invScalar, powScalar } from "../src/util/scalar";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";

test("powScalar", () => {
    const n = ForeignScalar.from(42);
    const exp = 5;
    const res = Scalar.from(130691232); // from python

    expect(powScalar(n, exp).toBigInt().toString()).toEqual(res.toBigInt().toString());
})


// test("invScalar", () => {
//     // Create random Scalar
//     const rand_base = Scalar.from(Math.floor(Math.random() * 16));
//     const rand_exp = Math.floor(Math.random() * 32);
//     const n = powScalar(rand_base, rand_exp);
// 
//     expect(n.mul(invScalar(n))).toEqual(Scalar.from(1));
// })
