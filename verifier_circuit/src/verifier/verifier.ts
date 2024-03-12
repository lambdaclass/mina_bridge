import { readFileSync } from 'fs';
import { circuitMainBn254, CircuitBn254, Group, public_, ForeignGroup, Provable } from 'o1js';
import { OpeningProof, PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { fp_sponge_initial_state, fp_sponge_params, fq_sponge_initial_state, fq_sponge_params, Sponge } from './sponge.js';
import { Alphas } from '../alphas.js';
import { Polynomial } from '../polynomial.js';
import { Linearization, PolishToken } from '../prover/expr.js';
import { ForeignBase } from '../foreign_fields/foreign_field.js';
import { ForeignScalar } from '../foreign_fields/foreign_scalar.js';
import {
    //LookupSelectors,
    LookupInfo, LookupSelectors
} from '../lookups/lookups.js';
import { Batch } from './batch.js';
import proof_json from "../../test_data/proof.json" assert { type: "json" };
import verifier_index_json from "../../test_data/verifier_index.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";
import { deserProverProof } from '../serde/serde_proof.js';
import { isErr, isOk, unwrap } from '../error.js';
import { finalVerify, BWParameters } from "./commitment.js";

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./test_data/steps.json", "utf-8"));
} catch (e) {
    steps = [];
}

let { h } = SRS.createFromJSON();

/*
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LookupVerifierIndex<G: CommitmentCurve> {
    pub joint_lookup_used: bool,
    #[serde(bound = "PolyComm<G>: Serialize + DeserializeOwned")]
    pub lookup_table: Vec<PolyComm<G>>,
    #[serde(bound = "PolyComm<G>: Serialize + DeserializeOwned")]
    pub lookup_selectors: LookupSelectors<PolyComm<G>>,

    /// Table IDs for the lookup values.
    /// This may be `None` if all lookups originate from table 0.
    #[serde(bound = "PolyComm<G>: Serialize + DeserializeOwned")]
    pub table_ids: Option<PolyComm<G>>,

    /// Information about the specific lookups used
    pub lookup_info: LookupInfo,

    /// An optional selector polynomial for runtime tables
    #[serde(bound = "PolyComm<G>: Serialize + DeserializeOwned")]
    pub runtime_tables_selector: Option<PolyComm<G>>,
}
*/

export class LookupVerifierIndex {
    joint_lookup_used: boolean
    lookup_table: PolyComm<ForeignGroup>[]
    lookup_selectors: LookupSelectors

    /// Table IDs for the lookup values.
    /// This may be `None` if all lookups originate from table 0.
    table_ids?: PolyComm<ForeignGroup>

    /// Information about the specific lookups used
    lookup_info: LookupInfo

    /// An optional selector polynomial for runtime tables
    runtime_tables_selector?: PolyComm<ForeignGroup>
}

/**
* Will contain information necessary for executing a verification
*/
export class VerifierIndex {
    domain_size: number
    domain_gen: ForeignScalar
    /** maximal size of polynomial section */
    max_poly_size: number
    /** the number of randomized rows to achieve zero knowledge */
    zk_rows: number
    srs: SRS
    /** number of public inputs */
    public: number
    /** number of previous evaluation challenges */
    prev_challenges: number

    /** permutation commitments */
    sigma_comm: PolyComm<ForeignGroup>[] // size PERMUTS
    /** coefficient commitment array */
    coefficients_comm: PolyComm<ForeignGroup>[] // size COLUMNS
    /** generic commitment */
    generic_comm: PolyComm<ForeignGroup>

    /** poseidon constraint selector polynomial commitments */
    psm_comm: PolyComm<ForeignGroup>

    /** EC addition selector polynomial commitment */
    complete_add_comm: PolyComm<ForeignGroup>
    /** EC variable base scalar multiplication selector polynomial commitment */
    mul_comm: PolyComm<ForeignGroup>
    /** endoscalar multiplication selector polynomial commitment */
    emul_comm: PolyComm<ForeignGroup>
    /** endoscalar multiplication scalar computation selector polynomial commitment */
    endomul_scalar_comm: PolyComm<ForeignGroup>

    /** RangeCheck0 polynomial commitments */
    range_check0_comm?: PolyComm<ForeignGroup>
    /** RangeCheck1 polynomial commitments */
    range_check1_comm?: PolyComm<ForeignGroup>
    /** Foreign field addition polynomial commitments */
    foreign_field_add_comm?: PolyComm<ForeignGroup>
    /** Foreign field multiplication polynomial commitments */
    foreign_field_mul_comm?: PolyComm<ForeignGroup>

    /** Xor commitments */
    xor_comm?: PolyComm<ForeignGroup>
    /** Rot commitments */
    rot_comm?: PolyComm<ForeignGroup>

    /** Wire coordinate shifts */
    shift: ForeignScalar[] // of size PERMUTS
    /** Zero knowledge polynomial */
    permutation_vanishing_polynomial_m: Polynomial

    /** Domain offset for zero-knowledge */
    w: ForeignScalar

    /** Endoscalar coefficient */
    endo: ForeignScalar

    lookup_index?: LookupVerifierIndex

    linearization: Linearization<PolishToken[]>

    /** The mapping between powers of alpha and constraints */
    powers_of_alpha: Alphas

    constructor(
        domain_size: number,
        domain_gen: ForeignScalar,
        max_poly_size: number,
        zk_rows: number,
        public_size: number,
        sigma_comm: PolyComm<ForeignGroup>[],
        coefficients_comm: PolyComm<ForeignGroup>[],
        generic_comm: PolyComm<ForeignGroup>,
        psm_comm: PolyComm<ForeignGroup>,
        complete_add_comm: PolyComm<ForeignGroup>,
        mul_comm: PolyComm<ForeignGroup>,
        emul_comm: PolyComm<ForeignGroup>,
        endomul_scalar_comm: PolyComm<ForeignGroup>,
        powers_of_alpha: Alphas,
        shift: ForeignScalar[],
        permutation_vanishing_polynomial_m: Polynomial,
        w: ForeignScalar,
        endo: ForeignScalar,
        linearization: Linearization<PolishToken[]>,
        range_check0_comm?: PolyComm<ForeignGroup>,
        range_check1_comm?: PolyComm<ForeignGroup>,
        foreign_field_add_comm?: PolyComm<ForeignGroup>,
        foreign_field_mul_comm?: PolyComm<ForeignGroup>,
        xor_comm?: PolyComm<ForeignGroup>,
        rot_comm?: PolyComm<ForeignGroup>,
        lookup_index?: LookupVerifierIndex
    ) {
        this.srs = SRS.createFromJSON();
        this.domain_size = domain_size;
        this.domain_gen = domain_gen;
        this.max_poly_size = max_poly_size;
        this.zk_rows = zk_rows;
        this.public = public_size;
        this.sigma_comm = sigma_comm;
        this.coefficients_comm = coefficients_comm;
        this.generic_comm = generic_comm;
        this.psm_comm = psm_comm;
        this.complete_add_comm = complete_add_comm;
        this.mul_comm = mul_comm;
        this.emul_comm = emul_comm;
        this.endomul_scalar_comm = endomul_scalar_comm;
        this.range_check0_comm = range_check0_comm;
        this.range_check1_comm = range_check1_comm;
        this.foreign_field_add_comm = foreign_field_add_comm;
        this.foreign_field_mul_comm = foreign_field_mul_comm;
        this.xor_comm = xor_comm;
        this.rot_comm = rot_comm;
        this.shift = shift;
        this.permutation_vanishing_polynomial_m = permutation_vanishing_polynomial_m;
        this.w = w;
        this.endo = endo;
        this.linearization = linearization;
        this.powers_of_alpha = powers_of_alpha;
        this.lookup_index = lookup_index;
    }

    /*
    * Compute the digest of the VerifierIndex, which can be used for the Fiat-Shamir transform.
    */
    digest(): ForeignBase {
        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());

        this.sigma_comm.forEach((g) => fq_sponge.absorbGroups(g.unshifted));
        this.coefficients_comm.forEach((g) => fq_sponge.absorbGroups(g.unshifted));
        fq_sponge.absorbGroups(this.generic_comm.unshifted);
        fq_sponge.absorbGroups(this.psm_comm.unshifted);
        fq_sponge.absorbGroups(this.complete_add_comm.unshifted);
        fq_sponge.absorbGroups(this.mul_comm.unshifted);
        fq_sponge.absorbGroups(this.emul_comm.unshifted);
        fq_sponge.absorbGroups(this.endomul_scalar_comm.unshifted);

        return fq_sponge.squeezeField();
    }
}

export class Verifier extends CircuitBn254 {
    /** Number of total registers */
    static readonly COLUMNS: number = 15;
    /** Number of registers that can be wired (participating in the permutation) */
    static readonly PERMUTS: number = 7;
    static readonly PERMUTATION_CONSTRAINTS: number = 3;

    @circuitMainBn254
    static main(@public_ openingProof: OpeningProof, @public_ expected: ForeignGroup) {
        let proverProof = deserProverProof(proof_json);

        const verifierIndex = deserVerifierIndex(verifier_index_json);
        let evaluationProofResult = Batch.toBatch(verifierIndex, proverProof, []);
        if (isErr(evaluationProofResult)) return evaluationProofResult;
        const evaluationProof = unwrap(evaluationProofResult);

        finalVerify(
            verifierIndex.srs,
            new BWParameters(),
            evaluationProof
        );
    }

    static naiveMSM(points: ForeignGroup[], scalars: ForeignScalar[]): ForeignGroup {
        let result = new ForeignGroup(ForeignBase.from(0), ForeignBase.from(0));

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            result = result.add(point.scale(scalar));
        }

        return result;
    }
}
