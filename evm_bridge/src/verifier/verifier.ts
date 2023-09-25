import assert from 'assert';
import { readFileSync } from 'fs';
import { Group, Scalar, Field } from 'o1js';
import { PolyComm } from '../poly_commitment/commitment.js';
import { SRS } from '../SRS.js';
import { Sponge } from './sponge.js';

let steps: bigint[][];
try {
    steps = JSON.parse(readFileSync("./src/steps.json", "utf-8"));
} catch (e) {
    steps = [];
}

let { g, h } = SRS.createFromJSON();

/*
* Will contain information necessary for executing a verification
*/
export class VerifierIndex {
    srs: SRS
    domain_size: number
    public: number

    /* permutation commitments */
    sigma_comm: PolyComm<Group>[] // size PERMUTS
    coefficients_comm: PolyComm<Group>[] // size COLUMNS
    generic_comm: PolyComm<Group>

    /* poseidon constraint selector polynomial commitments */
    psm_comm: PolyComm<Group>

    /* EC addition selector polynomial commitment */
    complete_add_comm: PolyComm<Group>
    /* EC variable base scalar multiplication selector polynomial commitment */
    mul_comm: PolyComm<Group>
    /* endoscalar multiplication selector polynomial commitment */
    emul_comm: PolyComm<Group>
    /* endoscalar multiplication scalar computation selector polynomial commitment */
    endomul_scalar_comm: PolyComm<Group>

    /*
    * Compute the digest of the VerifierIndex, which can be used for the Fiat-Shamir transform.
    */
    digest(): Field {
        let fq_sponge = new Sponge;

        this.sigma_comm.forEach((g) => fq_sponge.absorbGroups(g.unshifted));
        this.coefficients_comm.forEach((g) => fq_sponge.absorbGroups(g.unshifted));
        fq_sponge.absorbGroups(this.generic_comm.unshifted);
        fq_sponge.absorbGroups(this.psm_comm.unshifted);
        fq_sponge.absorbGroups(this.complete_add_comm.unshifted);
        fq_sponge.absorbGroups(this.mul_comm.unshifted);
        fq_sponge.absorbGroups(this.emul_comm.unshifted);
        fq_sponge.absorbGroups(this.endomul_scalar_comm.unshifted);

        return fq_sponge.squeeze();
    }
}

export class Verifier {
    static readonly PERMUTS: number = 7;
    static readonly COLUMNS: number = 15;

    static main(sg: Group, z1: bigint, expected: Group, debug: boolean) {
        let nonzero_length = g.length;
        let max_rounds = Math.ceil(Math.log2(nonzero_length));
        let padded_length = Math.pow(2, max_rounds);
        let padding = padded_length - nonzero_length;

        let points = [h];
        points = points.concat(g);
        points = points.concat(Array(padding).fill(Group.zero));

        let scalars = [0n];
        //TODO: Add challenges and s polynomial (in that case, using Scalars we could run out of memory)
        scalars = scalars.concat(Array(padded_length).fill(1n));
        assert(points.length == scalars.length, "The number of points is not the same as the number of scalars");

        points.push(sg);
        scalars.push(mod(-z1 - 1n));

        if (debug) {
            Verifier.msmDebug(points, scalars).assertEquals(expected);
        } else {
            Verifier.msm(points, scalars).assertEquals(expected);
        }
    }

    // Naive algorithm
    static msm(points: Group[], scalars: bigint[]) {
        let result = Group.zero;

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            result = result.add(point.scale(scalar));
        }

        return result;
    }

    // Naive algorithm (used for debugging)
    static msmDebug(points: Group[], scalars: bigint[]) {
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

function mod(n: bigint) {
    return ((n % Scalar.ORDER) + Scalar.ORDER) % Scalar.ORDER;
}
