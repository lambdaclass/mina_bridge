import { Scalar } from "o1js"
import { PointEvaluations, ProofEvaluations } from "../prover/prover.js"

type PointEvals = PointEvaluations<Scalar[]>;

// NOTE: snake_case is necessary to match the JSON schemes.
interface PointEvalsJSON {
    zeta: string[]
    zeta_omega: string[]
}
interface LookupEvaluationsJSON {
    sorted: PointEvalsJSON[]
    aggreg: PointEvalsJSON
    table: PointEvalsJSON
    runtime?: PointEvalsJSON
}
interface ProofEvalsJSON {
    w: PointEvalsJSON[] // of size 15, total num of registers (columns)
    z: PointEvalsJSON
    s: PointEvalsJSON[] // of size 7 - 1, total num of wirable registers minus one
    coefficients: PointEvalsJSON[] // of size 15, total num of registers (columns)
    //lookup?: LookupEvaluationsJSON
    lookup: null,
    generic_selector: PointEvalsJSON
    poseidon_selector: PointEvalsJSON
}

/*
 * Deserializes a scalar point evaluation from JSON
 */
export function deserPointEval(json: PointEvalsJSON): PointEvals {
    const deserHexScalar = (str: string): Scalar => {
        if (!str.startsWith("0x")) str = "0x" + str;
        return Scalar.from(str);
    }
    const zeta = json.zeta.map(deserHexScalar);
    const zetaOmega = json.zeta_omega.map(deserHexScalar);
    return { zeta, zetaOmega };
}

/*
 * Deserializes scalar proof evaluations from JSON
 */
export function deserProofEvals(json: ProofEvalsJSON): ProofEvaluations<PointEvals> {
    const [
        w,
        s,
        coefficients
    ] = [json.w, json.s, json.coefficients].map(field => field.map(deserPointEval));
    const [
        z,
        genericSelector,
        poseidonSelector
    ] = [json.z, json.generic_selector, json.poseidon_selector].map(deserPointEval);

    // in the current json, there isn't a non-null lookup, so TS infers that it'll always be null.
    let lookup = undefined;
    // let lookup = undefined;
    // if (json.lookup) {
    //     const sorted = json.lookup.sorted.map(deserPointEval);
    //     const [aggreg, table] = [json.lookup.aggreg, json.lookup.table].map(deserPointEval);

    //     let runtime = undefined;
    //     if (json.lookup.runtime) {
    //         runtime = deserPointEval(json.lookup.runtime);
    //     }

    //     lookup = { sorted, aggreg, table, runtime };
    // }

    return { w, z, s, coefficients, lookup, genericSelector, poseidonSelector };
}
