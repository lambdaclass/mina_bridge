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
interface ProofEvalsJSON {
    w: PointEvalsJSON[] // of size 15, total num of registers (columns)
    z: PointEvalsJSON
    s: PointEvalsJSON[] // of size 7 - 1, total num of wirable registers minus one
    coefficients: PointEvalsJSON[] // of size 15, total num of registers (columns)
    generic_selector: PointEvalsJSON
    poseidon_selector: PointEvalsJSON
    complete_add_selector: PointEvalsJSON
    mul_selector: PointEvalsJSON
    emul_selector: PointEvalsJSON
    endomul_scalar_selector: PointEvalsJSON

    range_check0_selector: PointEvalsJSON | null
    range_check1_selector: PointEvalsJSON | null
    foreign_field_add_selector: PointEvalsJSON | null
    foreign_field_mul_selector: PointEvalsJSON | null
    xor_selector: PointEvalsJSON | null
    rot_selector: PointEvalsJSON | null

    lookup_aggregation: PointEvalsJSON | null
    lookup_table: PointEvalsJSON | null
    lookup_sorted: PointEvalsJSON[] | null[] // fixed size of 5
    runtime_lookup_table: PointEvalsJSON | null

    runtime_lookup_table_selector: PointEvalsJSON | null
    xor_lookup_selector: PointEvalsJSON | null
    lookup_gate_lookup_selector: PointEvalsJSON | null
    range_check_lookup_selector: PointEvalsJSON | null
    foreign_field_mul_lookup_selector: PointEvalsJSON | null

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
    if (str.startsWith("0x")) str = str.slice(1);

    // reverse endianness
    let rev_str = "0x";
    for (let i = str.length - 1; i > 0; i -= 2) {
        rev_str += str.charAt(i - 1);
        rev_str += str.charAt(i);
    }

    return ForeignScalar.from(rev_str);
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

    const [
        rangeCheck0Selector,
        rangeCheck1Selector,
        foreignFieldAddSelector,
        foreignFieldMulSelector,
        xorSelector,
        rotSelector,
        lookupAggregation,
        lookupTable,
        runtimeLookupTable,
        runtimeLookupTableSelector,
        xorLookupSelector,
        lookupGateLookupSelector,
        rangeCheckLookupSelector,
        foreignFieldMulLookupSelector,
    ] = [
        json.range_check0_selector,
        json.range_check1_selector,
        json.foreign_field_add_selector,
        json.foreign_field_mul_selector,
        json.xor_selector,
        json.rot_selector,
        json.lookup_aggregation,
        json.lookup_table,
        json.runtime_lookup_table,
        json.runtime_lookup_table_selector,
        json.xor_lookup_selector,
        json.lookup_gate_lookup_selector,
        json.range_check_lookup_selector,
        json.foreign_field_mul_lookup_selector,
    ].map((evals) => {
        if (evals) return deserPointEval(evals);
        return undefined;
    });

    const lookupSorted = json.lookup_sorted[0]
        ? json.lookup_sorted.map((evals) => deserPointEval(evals!))
        : undefined;

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
        undefined,
        rangeCheck0Selector,
        rangeCheck1Selector,
        foreignFieldAddSelector,
        foreignFieldMulSelector,
        xorSelector,
        rotSelector,
        lookupAggregation,
        lookupTable,
        lookupSorted,
        runtimeLookupTable,
        runtimeLookupTableSelector,
        xorLookupSelector,
        lookupGateLookupSelector,
        rangeCheckLookupSelector,
        foreignFieldMulLookupSelector,
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
