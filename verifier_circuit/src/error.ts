export type VerifierOk<T> = { state: "ok", data: T };
export type VerifierErr = { state: "err", msg: string };

export type VerifierResult<T> = VerifierOk<T> | VerifierErr;

export function verifierErr<T>(msg: string): VerifierResult<T> {
    return { state: "err", msg }
}

export function verifierOk<T>(data: T): VerifierResult<T> {
    return { state: "ok", data }
}

export function isOk<T>(result: VerifierResult<T>): result is VerifierOk<T> {
    return result.state === "ok";
}

export function isErr<T>(result: VerifierResult<T>): result is VerifierErr {
    return result.state === "err";
}

export function unwrap<T>(result: VerifierResult<T>): T {
    let ok: T | undefined;
    if (isOk(result)) {
        ok = result.data;
    }
    return ok!;
}
