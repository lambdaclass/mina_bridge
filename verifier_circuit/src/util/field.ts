import { Provable, ProvableBn254 } from "../o1js/src/index.ts";
import { ForeignBase } from "../foreign_fields/foreign_field.ts";

export function sqrtBase(a: ForeignBase): ForeignBase | undefined {
    // Euler's criterion:
    const leg_sym = legendre_symbol(a);
    if (leg_sym.assertCanonical().equals(ForeignBase.modulus - 1n)) return undefined;
    return tonellishanks(a);
}

function legendre_symbol(a: ForeignBase): ForeignBase {
    return powBaseBig(a, (ForeignBase.modulus - 1n) / 2n);
}

// https://eprint.iacr.org/2012/685.pdf
// algorithm 5
function tonellishanks(a: ForeignBase): ForeignBase | undefined {
    const [t, s] = get_t_and_s();

    let c0 = ForeignBase.from(1);
    let z = ForeignBase.from(1);

    // we need to sample a random element `c`.
    // For this we're going to initialize `c to a
    // one and multiply it by a random power of `g`,
    // where `g` is a generator of the field.
    // This is because we can't generate random bigints
    // without using external libraries.
    let c = ForeignBase.from(1);

    // https://github.com/o1-labs/proof-systems/blob/master/curves/src/pasta/fields/fp.rs
    let g = ForeignBase.from(5);

    while (c0.equals(1)) {
        const rand_pow = Math.round(Math.random() * Number.MAX_SAFE_INTEGER);
        c = c.mul(powBase(g.assertCanonical(), rand_pow).assertCanonical()).assertCanonical();

        z = powBaseBig(c, t).assertCanonical();

        c0 = powBase(c, 1 << (s - 1)).assertCanonical();
    }

    let w = powBaseBig(a, (t - 1n) / 2n);

    let a0 = powBase(a.assertAlmostReduced().mul(w.assertAlmostReduced()).assertAlmostReduced().mul(w.assertAlmostReduced()).assertAlmostReduced(), 1 << (s - 1));

    if (a0.assertCanonical().equals(ForeignBase.modulus - 1n)) {
        return undefined
    }

    let v = s;
    let x = a.assertAlmostReduced().mul(w.assertAlmostReduced());
    let b = x.assertAlmostReduced().mul(w.assertAlmostReduced());

    while (!b.assertCanonical().equals(1)) {
        // find least integer k such taht b^(2^k) = 1:
        let temp = b;
        let k = 0;
        while (!temp.assertCanonical().equals(1)) {
            k += 1;
            temp = powBase(b.assertAlmostReduced(), 1 << k);
        }

        w = powBase(z, 1 << (v - k - 1));
        z = w.assertAlmostReduced().mul(w.assertAlmostReduced()).assertCanonical();
        b = b.assertAlmostReduced().mul(z.assertAlmostReduced());
        x = x.assertAlmostReduced().mul(w.assertAlmostReduced());
        v = k;
    }

    return ForeignBase.from(x).assertAlmostReduced();
}

function get_t_and_s(): [bigint, number] {
    const t = 6739986666787659948666753771754907668419893943225396963757154709741n;
    const s = 32;
    // generated from util/t_and_s.py

    return [t, s];
}

export function powBase(f: ForeignBase, exp: number): ForeignBase {
    if (exp === 0) return ForeignBase.from(1);
    else if (exp === 1) return f;
    else {
        let res = f;

        while ((exp & 1) === 0) {
            res = res.assertAlmostReduced().mul(res.assertAlmostReduced()).assertAlmostReduced();
            exp >>= 1;
        }

        if (exp === 0) {
            return res;
        } else {
            let base = res;
            exp >>= 1;

            while (exp !== 0) {
                base = base.assertAlmostReduced().mul(base.assertAlmostReduced()).assertAlmostReduced();
                if ((exp & 1) === 1) {
                    res = res.assertAlmostReduced().mul(base.assertAlmostReduced()).assertAlmostReduced();
                }
                exp >>= 1;
            }

            return res;
        }
    }
}

export function powBaseBig(f: ForeignBase, exp: bigint): ForeignBase {
    if (exp === 0n) return ForeignBase.from(1);
    else if (exp === 1n) return f;
    else {
        let res = f;

        while ((exp & 1n) === 0n) {
            res = res.assertAlmostReduced().mul(res.assertAlmostReduced()).assertAlmostReduced();
            exp >>= 1n;
        }

        if (exp === 0n) return res;
        else {
            let base = res;
            exp >>= 1n;

            while (exp !== 0n) {
                base = base.assertAlmostReduced().mul(base.assertAlmostReduced()).assertAlmostReduced();
                if ((exp & 1n) === 1n) {
                    res = res.assertAlmostReduced().mul(base.assertAlmostReduced()).assertAlmostReduced();
                }
                exp >>= 1n;
            }

            return res;
        }
    }
}

/**
 * Extended euclidean algorithm. Returns [gcd, Bezout_a, Bezout_b]
 * so gcd = a*Bezout_a + b*Bezout_b.
 * source: https://www.extendedeuclideanalgorithm.com/code
 */
function xgcd(
    a: bigint,
    b: bigint,
    s1 = 1n,
    s2 = 0n,
    t1 = 0n,
    t2 = 1n
): [bigint, bigint, bigint] {
    if (b === 0n) {
        return [a, 1n, 0n];
    }

    let q = a / b;
    let r = a - q * b;
    let s3 = s1 - q * s2;
    let t3 = t1 - q * t2;

    return (r === 0n) ? [b, s2, t2] : xgcd(b, r, s2, s3, t2, t3);
}


export function invBase(f: ForeignBase): ForeignBase {
    let result = ForeignBase.from(0);
    ProvableBn254.asProver(() => {
        const [gcd, inv, _] = xgcd(f.toBigInt(), ForeignBase.modulus);
        if (gcd !== 1n) {
            // FIXME: error
        }

        result = ForeignBase.from(inv);
    });

    return result;
}
