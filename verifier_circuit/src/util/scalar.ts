import { Provable, Scalar } from "o1js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

export function powScalar(f: ForeignScalar, exp: number): ForeignScalar {
    if (exp === 0) return ForeignScalar.from(1);
    else if (exp === 1) return f;
    else {
        let res = f;

        while ((exp & 1) === 0) {
            res = res.mul(res);
            exp >>= 1;
        }

        if (exp === 0) return res;
        else {
            let base = res;
            exp >>= 1;

            while (exp !== 0) {
                base = base.mul(base);
                if ((exp & 1) === 1) {
                    res = res.mul(base);
                }
                exp >>= 1;
            }

            return res;
        }
    }
}

export function powScalarBig(f: Scalar, exp: bigint): Scalar {
    let res = f;
    for (let _ = 1n; _ < exp; _++) {
        res = res.mul(f);
    }
    return res
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


export function invScalar(f: ForeignScalar): ForeignScalar {
    let result = ForeignScalar.from(0);
    Provable.asProverBn254(() => {
        const [gcd, inv, _] = xgcd(f.toBigIntBn254(), Scalar.ORDER);
        if (gcd !== 1n) {
            // FIXME: error
        }

        result = ForeignScalar.from(inv);
    });

    return result;
}
