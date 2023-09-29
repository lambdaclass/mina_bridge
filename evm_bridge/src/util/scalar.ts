function powScalar(f: Field, exp: number): Field => {
    let res = f;
    for (let _ = 1; _ < exp; _++) {
        res = res.mul(f);
    }
    return f
}
