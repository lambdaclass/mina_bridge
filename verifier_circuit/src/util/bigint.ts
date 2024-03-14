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

/**
 * Recomposes 64-bit `limbs` into a bigint, less significant first
 */
export function fromLimbs64(limbs: bigint[]): bigint {
    let n_rebuilt = 0n;
    for (const limb of limbs) {
        n_rebuilt <<= 64n
        n_rebuilt += limb;
    }
    return n_rebuilt;
}

/**
 * Recomposes 64-bit `limbs` into a bigint, more significant first
 */
export function fromLimbs64Rev(limbs: bigint[]): bigint {
    let n_rebuilt = 0n;
    for (const limb of limbs.reverse()) {
        n_rebuilt <<= 64n
        n_rebuilt += limb;
    }
    return n_rebuilt;
}
