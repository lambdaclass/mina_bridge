import { OpeningProof } from "../poly_commitment/opening_proof.ts";
import { PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof, RecursionChallenge } from "../prover/prover.ts"
import { deserPolyComm, PolyCommJSON, deserGroup, GroupJSON } from "./serde_index.ts";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.ts";
import { PolyComm } from "../poly_commitment/commitment.ts";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.ts";

type PointEvals = PointEvaluations;

export type PointEvalsJSON = string[][];

export interface ProofEvalsJSON {
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
    w_comm: GroupJSON[]
    z_comm: GroupJSON
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

    return ForeignScalar.from(rev_str).assertAlmostReduced();
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
    let zeta;
    let zetaOmega;

    if (Array.isArray(json[0])) {
        zeta = json[0].map(deserHexScalar)[0];
    } else {
        zeta = deserHexScalar(json[0]);
    }
    if (Array.isArray(json[1])) {
        zetaOmega = json[1].map(deserHexScalar)[0];
    } else {
        zetaOmega = deserHexScalar(json[1]);
    }

    return new PointEvaluations(zeta, zetaOmega);
}

/**
 * Deserializes scalar proof evaluations from JSON
 */
export function deserProofEvals(proofEvalsJson: ProofEvalsJSON, publicInputJson: PointEvalsJSON): ProofEvaluations {
    const [
        w,
        s,
        coefficients
    ] = [proofEvalsJson.w, proofEvalsJson.s, proofEvalsJson.coefficients].map(field => field.map(deserPointEval));
    const [
        z,
        genericSelector,
        poseidonSelector,
        completeAddSelector,
        mulSelector,
        emulSelector,
        endomulScalarSelector,
    ] = [
        proofEvalsJson.z,
        proofEvalsJson.generic_selector,
        proofEvalsJson.poseidon_selector,
        proofEvalsJson.complete_add_selector,
        proofEvalsJson.mul_selector,
        proofEvalsJson.emul_selector,
        proofEvalsJson.endomul_scalar_selector
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
        proofEvalsJson.range_check0_selector,
        proofEvalsJson.range_check1_selector,
        proofEvalsJson.foreign_field_add_selector,
        proofEvalsJson.foreign_field_mul_selector,
        proofEvalsJson.xor_selector,
        proofEvalsJson.rot_selector,
        proofEvalsJson.lookup_aggregation,
        proofEvalsJson.lookup_table,
        proofEvalsJson.runtime_lookup_table,
        proofEvalsJson.runtime_lookup_table_selector,
        proofEvalsJson.xor_lookup_selector,
        proofEvalsJson.lookup_gate_lookup_selector,
        proofEvalsJson.range_check_lookup_selector,
        proofEvalsJson.foreign_field_mul_lookup_selector,
    ].map((evals) => {
        if (evals) return deserPointEval(evals);
        return undefined;
    });

    const lookupSorted = proofEvalsJson.lookup_sorted[0]
        ? proofEvalsJson.lookup_sorted.map((evals) => deserPointEval(evals!))
        : undefined;

    const publicInput = deserPointEval(publicInputJson);

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
        publicInput,
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
    return new ProverCommitments(
        json.w_comm.map((item) => new PolyComm<ForeignPallas>([deserGroup(item)], undefined)),
        new PolyComm<ForeignPallas>([deserGroup((json.z_comm))], undefined),
        deserPolyComm(json.t_comm)
    );
}


export interface OpeningProofJSON {
    lr: GroupJSON[][] // [GroupJSON, GroupJSON][]
    delta: GroupJSON
    z_1: string
    z_2: string
    challenge_polynomial_commitment: GroupJSON
}

export function deserOpeningProof(json: OpeningProofJSON): OpeningProof {
    return new OpeningProof(
        json.lr.map((g) => [deserGroup(g[0]), deserGroup(g[1])]),
        deserGroup(json.delta),
        deserHexScalar(json.z_1),
        deserHexScalar(json.z_2),
        deserGroup(json.challenge_polynomial_commitment),
    )
}

interface PrevEvalsJSON {
    evals: { evals: ProofEvalsJSON, public_input: PointEvalsJSON }
    ft_eval1: string
}

interface ProverProofJSON {
    prev_evals: PrevEvalsJSON,
    proof: { bulletproof: OpeningProofJSON, commitments: ProverCommitmentsJSON }
}

export function deserProverProof(json: ProverProofJSON): ProverProof {
    const { prev_evals, proof } = json;
    const { evals: { evals, public_input }, ft_eval1 } = prev_evals;
    const { bulletproof, commitments } = proof;
    return new ProverProof(
        deserProofEvals(evals, public_input),
        [], //TODO
        deserProverCommitments(commitments),
        deserHexScalar(ft_eval1),
        deserOpeningProof(bulletproof)
    );
}
