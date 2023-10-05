import { Scalar } from "o1js";

export function powScalar(f: Scalar, exp: number): Scalar {
    let res = f;
    for (let _ = 1; _ < exp; _++) {
        res = res.mul(f);
    }
    return res
}

export function powScalarBig(f: Scalar, exp: bigint): Scalar {
    let res = f;
    for (let _ = 1n; _ < exp; _++) {
        res = res.mul(f);
    }
    return res
}

export function invScalar(f: Scalar): Scalar {
    if (f === Scalar.from(0)) {
        return Scalar.from(0);
        // FIXME: error
    }

    // using fermat's little theorem:
    return powScalarBig(f, Scalar.ORDER - 2n);
}
