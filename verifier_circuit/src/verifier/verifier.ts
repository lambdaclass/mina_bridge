import assert from 'assert';
import { readFileSync } from 'fs';
import { circuitMain, Circuit, Group, Scalar, public_, Field } from 'o1js';
import { PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { Sponge } from './sponge.js';
import { Alphas } from '../alphas.js';
import { Polynomial } from '../polynomial.js';
import { Linearization, PolishToken } from '../prover/expr.js';
import { ForeignScalar } from '../foreign_fields/foreign_scalar.js';
import { ForeignGroup } from '../foreign_fields/foreign_group.js';
import { ForeignField } from '../foreign_fields/foreign_field.js';

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./test/steps.json", "utf-8"));
} catch (e) {
    steps = [];
}

let { g, h } = SRS.createFromJSON();

// TODO: we are slicing G because we are implementing the foreign EC operations in o1js
// This is too slow, so we are using less elements.
g = g.slice(0, 4);

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
    static main(@public_ sg_x: ForeignField, @public_ sg_y: ForeignField, @public_ sg_scalar: ForeignScalar, @public_ expected_x: ForeignField, @public_ expected_y: ForeignField) {
        let sg = new ForeignGroup(sg_x, sg_y);
        let nonzero_length = g.length;
        let max_rounds = Math.ceil(Math.log2(nonzero_length));
        let padded_length = Math.pow(2, max_rounds);
        let padding = padded_length - nonzero_length;

        let points = [h];
        points = points.concat(g);
        points = points.concat(Array(padding).fill(ForeignGroup.zero()));

        let scalars = [ForeignScalar.from(0)];
        //TODO: Add challenges and s polynomial (in that case, using Scalars we could run out of memory)
        scalars = scalars.concat(Array(padded_length).fill(ForeignScalar.from(1)));
        assert(points.length == scalars.length, "The number of points is not the same as the number of scalars");

        points.push(sg);
        scalars.push(sg_scalar);

        let actual = Verifier.msm(points, scalars);
        let expected = new ForeignGroup(expected_x, expected_y);
        console.log("actual", actual.x, actual.y);
        console.log("expected", expected.x, expected.y);
        actual.assertEquals(expected);
    }

    // Naive algorithm
    static msm(points: ForeignGroup[], scalars: ForeignScalar[]) {
        let result = ForeignGroup.zero();

        for (let i = 0; i < points.length; i++) {
            console.log(i);
            let point = points[i];
            let scalar = scalars[i];
            let scaled = point.scale(scalar);
            result = result.add(scaled);
        }

        return result;
    }

    // Naive algorithm (used for debugging)
    static msmDebug(points: Group[], scalars: Scalar[]) {
        let result = Group.zero;

        if (steps.length === 0) {
            console.log("Steps file not found, skipping MSM check");
        }

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            result = result.add(point.scale(scalar));

            if (steps.length > 0 && (result.x.toBigInt() != steps[i][0] || result.y.toBigInt() != steps[i][1])) {
                console.log("Result differs at step", i);
            }
        }

        return result;
    }
}
