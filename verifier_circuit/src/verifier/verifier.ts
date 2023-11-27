import { readFileSync } from 'fs';
import { circuitMain, Circuit, Group, Scalar, public_, Field, ForeignGroup } from 'o1js';
import { PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { Sponge } from './sponge.js';
import { Alphas } from '../alphas.js';
import { Polynomial } from '../polynomial.js';
import { Linearization, PolishToken } from '../prover/expr.js';
import { ForeignField } from '../foreign_fields/foreign_field.js';
import { ForeignScalar } from '../foreign_fields/foreign_scalar.js';
import {
    //LookupSelectors,
    LookupInfo
} from '../lookups/lookups.js';

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./test/steps.json", "utf-8"));
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
    lookup_table: PolyComm<Group>[]
    // TODO !!! lookup_selectors: LookupSelectors<PolyComm<Group>>

    /// Table IDs for the lookup values.
    /// This may be `None` if all lookups originate from table 0.
    table_ids?: PolyComm<Group>

    /// Information about the specific lookups used
    lookup_info: LookupInfo

    /// An optional selector polynomial for runtime tables
    runtime_tables_selector?: PolyComm<Group>
}

/**
* Will contain information necessary for executing a verification
*/
export class VerifierIndex {
    srs: SRS
    domain_size: number
    domain_gen: Scalar
    /** number of public inputs */
    public: number
    /** maximal size of polynomial section */
    max_poly_size: number
    /** the number of randomized rows to achieve zero knowledge */
    zk_rows: number

    /** permutation commitments */
    sigma_comm: PolyComm<Group>[] // size PERMUTS
    coefficients_comm: PolyComm<Group>[] // size COLUMNS
    generic_comm: PolyComm<Group>

    /** poseidon constraint selector polynomial commitments */
    psm_comm: PolyComm<Group>

    /** EC addition selector polynomial commitment */
    complete_add_comm: PolyComm<Group>
    /** EC variable base scalar multiplication selector polynomial commitment */
    mul_comm: PolyComm<Group>
    /** endoscalar multiplication selector polynomial commitment */
    emul_comm: PolyComm<Group>
    /** endoscalar multiplication scalar computation selector polynomial commitment */
    endomul_scalar_comm: PolyComm<Group>

    /** The mapping between powers of alpha and constraints */
    powers_of_alpha: Alphas
    /** Wire coordinate shifts */
    shift: Scalar[] // of size PERMUTS
    /** Zero knowledge polynomial */
    permutation_vanishing_polynomial_m: Polynomial
    /** Domain offset for zero-knowledge */
    w: Scalar
    /** Endoscalar coefficient */
    endo: Scalar

    // TODO!
    ///pub lookup_index: Option<LookupVerifierIndex<G>>,

    linearization: Linearization<PolishToken[]>

    constructor(
        domain_size: number,
        domain_gen: Scalar,
        max_poly_size: number,
        zk_rows: number,
        public_size: number,
        sigma_comm: PolyComm<Group>[],
        coefficients_comm: PolyComm<Group>[],
        generic_comm: PolyComm<Group>,
        psm_comm: PolyComm<Group>,
        complete_add_comm: PolyComm<Group>,
        mul_comm: PolyComm<Group>,
        emul_comm: PolyComm<Group>,
        endomul_scalar_comm: PolyComm<Group>,
        powers_of_alpha: Alphas,
        shift: Scalar[],
        permutation_vanishing_polynomial_m: Polynomial,
        w: Scalar,
        endo: Scalar,
        linearization: Linearization<PolishToken[]>
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
        this.powers_of_alpha = powers_of_alpha;
        this.shift = shift;
        this.permutation_vanishing_polynomial_m = permutation_vanishing_polynomial_m;
        this.w = w;
        this.endo = endo;
        this.linearization = linearization;
    }

    /*
    * Compute the digest of the VerifierIndex, which can be used for the Fiat-Shamir transform.
    */
    digest(): Field {
        let fq_sponge = new Sponge();

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

export class Verifier extends Circuit {
    /** Number of total registers */
    static readonly COLUMNS: number = 15;
    /** Number of registers that can be wired (participating in the permutation) */
    static readonly PERMUTS: number = 7;
    static readonly PERMUTATION_CONSTRAINTS: number = 3;

    @circuitMain
    static main(@public_ sg: ForeignGroup, @public_ z1: ForeignScalar, @public_ expected: ForeignGroup) {
        let points = [h];
        let scalars = [ForeignScalar.from(0)];

        let randBase = ForeignScalar.from(1);
        let sgRandBase = ForeignScalar.from(1);
        let negRandBase = randBase.neg();

        points.push(sg);
        scalars.push(negRandBase.mul(z1).sub(sgRandBase));

        let result = Verifier.naiveMSM(points, scalars);

        result.assertEquals(expected);
    }

    static naiveMSM(points: ForeignGroup[], scalars: ForeignScalar[]): ForeignGroup {
        let result = new ForeignGroup(ForeignField.from(0), ForeignField.from(0));

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            result = result.add(point.scale(scalar));
        }

        return result;
    }
}
