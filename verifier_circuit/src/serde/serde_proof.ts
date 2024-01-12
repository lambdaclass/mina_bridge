import { Group, Proof, Scalar } from "o1js"
import { OpeningProof, PolyComm } from "../poly_commitment/commitment.js";
import { LookupEvaluations, PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof, RecursionChallenge } from "../prover/prover.js"
import { deserPolyComm, PolyCommJSON, deserGroup, GroupJSON } from "./serde_index.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

type PointEvals = PointEvaluations<ForeignScalar[]>;

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
    generic_selector: PointEvalsJSON
    poseidon_selector: PointEvalsJSON
    complete_add_selector: PointEvalsJSON
    mul_selector: PointEvalsJSON
    emul_selector: PointEvalsJSON
    endomul_scalar_selector: PointEvalsJSON
}

interface ProverCommitmentsJSON {
    w_comm: PolyCommJSON[]
    z_comm: PolyCommJSON
    t_comm: PolyCommJSON
}

/**
 * Deserializes a scalar from a hex string, prefix doesn't matter
 */
export function deserHexScalar(str: string): ForeignScalar {
    if (!str.startsWith("0x")) str = "0x" + str;
    return ForeignScalar.from(str);
}

/**
 * Deserializes a scalar from a dec string
 */
export function deserDecScalar(str: string): ForeignScalar {
    return ForeignScalar.from(str);
}

/**
 * Deserializes a scalar point evaluation from JSON
 */
export function deserPointEval(json: PointEvalsJSON): PointEvals {
    const zeta = json.zeta.map(deserHexScalar);
    const zetaOmega = json.zeta_omega.map(deserHexScalar);
    let ret = new PointEvaluations(zeta, zetaOmega);

    return ret;
}

/**
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
        poseidonSelector,
        completeAddSelector,
        mulSelector,
        emulSelector,
        endomulScalarSelector,
    ] = [
        json.z,
        json.generic_selector,
        json.poseidon_selector,
        json.complete_add_selector,
        json.mul_selector,
        json.emul_selector,
        json.endomul_scalar_selector
    ].map(deserPointEval);

    // in the current json, there isn't a non-null lookup, so TS infers that it'll always be null.
    let lookup = undefined;
    // let lookup = undefined;
    //   if (json.lookup) {
    //       const sorted = json.lookup.sorted.map(deserPointEval);
    //       const [aggreg, table] = [json.lookup.aggreg, json.lookup.table].map(deserPointEval);

    //       let runtime = undefined;
    //       if (json.lookup.runtime) {
    //           runtime = deserPointEval(json.lookup.runtime);
    //       }

    //       lookup = { sorted, aggreg, table, runtime };
    //   }

    return new ProofEvaluations(
        w,
        z,
        s,
        coefficients,
        genericSelector,
        poseidonSelector,
        completeAddSelector,
        mulSelector,
        emulSelector,
        endomulScalarSelector,
        lookup
    );
}

export function deserProverCommitments(json: ProverCommitmentsJSON): ProverCommitments {
    return {
        wComm: json.w_comm.map(deserPolyComm),
        zComm: deserPolyComm(json.z_comm),
        tComm: deserPolyComm(json.t_comm)
    };
}


interface OpeningProofJSON {
    lr: GroupJSON[][] // [GroupJSON, GroupJSON]
    delta: GroupJSON
    z1: string
    z2: string
    sg: GroupJSON
}

export function deserOpeningProof(json: OpeningProofJSON): OpeningProof {
    return new OpeningProof(
        json.lr.map((g) => [deserGroup(g[0]), deserGroup(g[1])]),
        deserGroup(json.delta),
        deserHexScalar(json.z1),
        deserHexScalar(json.z2),
        deserGroup(json.sg),
    )
}

interface ProverProofJSON {
    evals: ProofEvalsJSON
    prev_challenges: RecursionChallenge[]
    commitments: ProverCommitmentsJSON
    ft_eval1: string
    proof: OpeningProofJSON
}


export function deserProverProof(json: ProverProofJSON): ProverProof {
    const { evals, prev_challenges, commitments, ft_eval1, proof } = json;
    return new ProverProof(
        deserProofEvals(evals),
        prev_challenges,
        deserProverCommitments(commitments),
        deserHexScalar(ft_eval1),
        deserOpeningProof(proof)
    );
}
