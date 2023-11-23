import { readFileSync } from 'fs';
import { circuitMain, Circuit, Group, Scalar, public_, Field, ForeignGroup } from 'o1js';
import { PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { Sponge } from './sponge.js';
import { Alphas } from '../alphas.js';
import { Polynomial } from '../polynomial.js';
import { Linearization, PolishToken } from '../prover/expr.js';
import { ForeignField } from '../foreign_fields/foreign_field.js';

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./test/steps.json", "utf-8"));
} catch (e) {
    steps = [];
}

let { h } = SRS.createFromJSON();

/**
* Will contain information necessary for executing a verification
*/
export class VerifierIndex {
    srs: SRS<ForeignField>
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
    static main(@public_ sg: ForeignGroup<ForeignField>, @public_ expected: ForeignGroup<ForeignField>) {
        console.dir(sg, { depth: null });
        let actual = sg.add(h);
        console.log("expected.x class name", expected.x.constructor.name);
        console.log("is expected.x instance of ForeignField", expected.x instanceof ForeignField);
        actual.assertEquals(expected);
    }
}
