import { fromLimbs64, getLimbs64 } from "../src/util/bigint";

test("getLimbs64", () => {
    // Create random bigint
    const rand_exp = BigInt(
        Math.floor(Math.random() * 512)
    );
    const n = 1n << rand_exp;

    // Get limbs
    const limbs = getLimbs64(n);

    // Rebuild the bigint
    let n_rebuilt = 0n;
    for (const i in limbs) {
        n_rebuilt += limbs[i] << 64n*BigInt(i);
    }

    expect(n_rebuilt).toEqual(n);
})

test("fromLimbs64", () => {
    // Create random bigint
    const rand_exp = BigInt(
        Math.floor(Math.random() * 512)
    );
    const n = 1n << rand_exp;

    // Get limbs
    const limbs = getLimbs64(n);

    // Rebuild the bigint
    const n_rebuilt = fromLimbs64(limbs);

    expect(n_rebuilt).toEqual(n);
})
