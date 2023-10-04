/**
 * Decomposes `n` into 64 bit limbs, less significant first
*/
export function getLimbs64(n: bigint): bigint[] {
    const len = Math.floor(n.toString(2).length / 64);
    const mask_64 = (1n << 64n) - 1n;

    let limbs = [];
    for (let i = 0; i <= len; i++) {
        limbs[i] = n & mask_64;
        n >>= 64n;
    }

    return limbs;
}
