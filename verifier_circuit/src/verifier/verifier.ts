import { readFileSync } from 'fs';
import { CircuitBn254, FieldBn254, ProvableBn254, PoseidonBn254, circuitMainBn254, publicBn254 } from 'o1js';
import { PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { fp_sponge_initial_state, fp_sponge_params, Sponge } from './sponge.js';
import { Alphas } from '../alphas.js';
import { Polynomial } from '../polynomial.js';
import { Linearization, PolishToken } from '../prover/expr.js';
import { ForeignBase } from '../foreign_fields/foreign_field.js';
import { ForeignScalar } from '../foreign_fields/foreign_scalar.js';
import {
    LookupInfo, LookupSelectors
} from '../lookups/lookups.js';
import { Batch } from './batch.js';
import verifier_index_json from "../../test_data/verifier_index.json" assert { type: "json" };
import proof_json from "../../test_data/proof.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";
import { ForeignPallas, pallasZero } from '../foreign_fields/foreign_pallas.js';
import { isErr, isOk, unwrap, VerifierResult, verifierOk } from '../error.js';
import { finalVerify, BWParameters } from "./commitment.js";
import { OpeningProof } from '../poly_commitment/opening_proof.js';
import { deserProverProof } from '../serde/serde_proof.js';

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./test_data/steps.json", "utf-8"));
} catch (e) {
    steps = [];
}

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
    lookup_table: PolyComm<ForeignPallas>[]
    lookup_selectors: LookupSelectors

    /// Table IDs for the lookup values.
    /// This may be `None` if all lookups originate from table 0.
    table_ids?: PolyComm<ForeignPallas>

    /// Information about the specific lookups used
    lookup_info: LookupInfo

    /// An optional selector polynomial for runtime tables
    runtime_tables_selector?: PolyComm<ForeignPallas>
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
    sigma_comm: PolyComm<ForeignPallas>[] // size PERMUTS
    coefficients_comm: PolyComm<ForeignPallas>[] // size COLUMNS
    generic_comm: PolyComm<ForeignPallas>

    /** poseidon constraint selector polynomial commitments */
    psm_comm: PolyComm<ForeignPallas>

    /** EC addition selector polynomial commitment */
    complete_add_comm: PolyComm<ForeignPallas>
    /** EC variable base scalar multiplication selector polynomial commitment */
    mul_comm: PolyComm<ForeignPallas>
    /** endoscalar multiplication selector polynomial commitment */
    emul_comm: PolyComm<ForeignPallas>
    /** endoscalar multiplication scalar computation selector polynomial commitment */
    endomul_scalar_comm: PolyComm<ForeignPallas>

    /** RangeCheck0 polynomial commitments */
    range_check0_comm?: PolyComm<ForeignPallas>
    /** RangeCheck1 polynomial commitments */
    range_check1_comm?: PolyComm<ForeignPallas>
    /** Foreign field addition polynomial commitments */
    foreign_field_add_comm?: PolyComm<ForeignPallas>
    /** Foreign field multiplication polynomial commitments */
    foreign_field_mul_comm?: PolyComm<ForeignPallas>

    /** Xor commitments */
    xor_comm?: PolyComm<ForeignPallas>
    /** Rot commitments */
    rot_comm?: PolyComm<ForeignPallas>

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
        sigma_comm: PolyComm<ForeignPallas>[],
        coefficients_comm: PolyComm<ForeignPallas>[],
        generic_comm: PolyComm<ForeignPallas>,
        psm_comm: PolyComm<ForeignPallas>,
        complete_add_comm: PolyComm<ForeignPallas>,
        mul_comm: PolyComm<ForeignPallas>,
        emul_comm: PolyComm<ForeignPallas>,
        endomul_scalar_comm: PolyComm<ForeignPallas>,
        powers_of_alpha: Alphas,
        shift: ForeignScalar[],
        permutation_vanishing_polynomial_m: Polynomial,
        w: ForeignScalar,
        endo: ForeignScalar,
        linearization: Linearization<PolishToken[]>,
        range_check0_comm?: PolyComm<ForeignPallas>,
        range_check1_comm?: PolyComm<ForeignPallas>,
        foreign_field_add_comm?: PolyComm<ForeignPallas>,
        foreign_field_mul_comm?: PolyComm<ForeignPallas>,
        xor_comm?: PolyComm<ForeignPallas>,
        rot_comm?: PolyComm<ForeignPallas>,
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
    static main(@publicBn254 proofAndMerkleHashInput: FieldBn254) {
        let proof = ProvableBn254.witness(OpeningProof, () => {
            let openingProofFields: string[] = JSON.parse(readFileSync("./src/opening_proof_fields.json", "utf-8"));

            return OpeningProof.fromFields(openingProofFields.map(FieldBn254));
        });
        let merkleRoot = ProvableBn254.witness(FieldBn254, () => {
            let rootString: string[] = JSON.parse(readFileSync("./src/merkle_root.json", "utf-8"));
            return FieldBn254(rootString[0]);
        });
        let proofHash = proof.hash();
        let proofAndMerkleHash = PoseidonBn254.hash([proofHash, merkleRoot]);

        proofAndMerkleHashInput.assertEquals(proofAndMerkleHash);

        // if the proof is successful, this will be 1. Else will be 0.
        let success = ForeignScalar.from(0).assertAlmostReduced();

        const verifier_result = this.verifyProof(proof);
        if (isOk(verifier_result)) {
            const verifier_successful = unwrap(verifier_result);
            if (verifier_successful) success = ForeignScalar.from(1).assertAlmostReduced();
        }

        //success.assertEquals(ForeignScalar.from(1).assertAlmostReduced());
    }

    static verifyProof(openingProof: OpeningProof): VerifierResult<boolean> {
        const proverProof = deserProverProof(proof_json);
        proverProof.proof = openingProof;
        const verifierIndex = deserVerifierIndex(verifier_index_json);
        let evaluationProofResult = Batch.toBatch(verifierIndex, proverProof, []);
        if (isErr(evaluationProofResult)) return evaluationProofResult;
        const evaluationProof = unwrap(evaluationProofResult);

        return verifierOk(finalVerify(
            verifierIndex.srs,
            new BWParameters(),
            evaluationProof
        ));
    }

    static naiveMSM(points: ForeignPallas[], scalars: ForeignScalar[]): ForeignPallas {
        let result = pallasZero();

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            // FIXME: This should scale the point, but it is not working yet
            // result = result.completeAdd(point.completeScale(scalar));
            result = result.completeAdd(point) as ForeignPallas;
        }

        return result;
    }
}
