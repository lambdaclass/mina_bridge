import { Scalar } from "o1js";

export function powScalar(f: Scalar, exp: number): Scalar {
    let res = f;
    for (let _ = 1; _ < exp; _++) {
        res = res.mul(f);
    }
    return f
}
