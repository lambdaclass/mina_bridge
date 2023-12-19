import { Field, ForeignGroup, Group, Scalar } from "o1js";
import { Sponge } from "../verifier/sponge";
import { ForeignField } from "../foreign_fields/foreign_field.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

/**
* A polynomial commitment
*/
export class PolyComm<A> {
    unshifted: A[]
    shifted?: A

    constructor(unshifted: A[], shifted?: A) {
        this.unshifted = unshifted;
        this.shifted = shifted;
    }

    /**
    * Zips two commitments into one
    */
    zip<B>(other: PolyComm<B>): PolyComm<[A, B]> {
        let unshifted = this.unshifted.map((u, i) => [u, other.unshifted[i]] as [A, B]);
        let shifted = (this.shifted && other.shifted) ?
            [this.shifted, other.shifted] as [A, B] : undefined;
        return new PolyComm<[A, B]>(unshifted, shifted);
    }

    /**
    * Maps over self's `unshifted` and `shifted`
    */
    map<B>(f: (x: A) => B): PolyComm<B> {
        let unshifted = this.unshifted.map(f);
        let shifted = (this.shifted) ? f(this.shifted) : undefined;
        return new PolyComm<B>(unshifted, shifted);
    }

    /**
     * Substract two commitments
     */
    static sub(lhs: PolyComm<ForeignGroup>, rhs: PolyComm<ForeignGroup>): PolyComm<ForeignGroup> {
        let unshifted = [];
        const n1 = lhs.unshifted.length;
        const n2 = rhs.unshifted.length;

        for (let i = 0; i < Math.max(n1, n2); i++) {
            const pt = i < n1 && i < n2 ?
                lhs.unshifted[i].sub(rhs.unshifted[i]) :
                i < n1 ? lhs.unshifted[i] : rhs.unshifted[i];
            unshifted.push(pt);
        }

        let shifted;
        if (lhs.shifted == undefined) shifted = rhs.shifted;
        else if (rhs.unshifted == undefined) shifted = lhs.shifted;
        else shifted = rhs.shifted?.sub(lhs.shifted);

        return new PolyComm(unshifted, shifted);
    }

    /**
     * Scale a commitments
     */
    static scale(v: PolyComm<ForeignGroup>, c: ForeignScalar) {
        return new PolyComm(v.unshifted.map((u) => u.scale(c)), v.shifted?.scale(c));
    }

    /**
    * Execute a simple multi-scalar multiplication
    */
    static naiveMSM(points: ForeignGroup[], scalars: ForeignScalar[]) {
        let result = new ForeignGroup(ForeignField.from(0), ForeignField.from(0));

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            result = result.add(point.scale(scalar));
        }

        return result;
    }

    /**
    * Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
    * If empty, returns a commitment with the point at infinity.
    */
    static msm(com: PolyComm<ForeignGroup>[], elm: ForeignScalar[]): PolyComm<ForeignGroup> {
        if (com.length === 0 || elm.length === 0) {
            return new PolyComm<ForeignGroup>([new ForeignGroup(ForeignField.from(0), ForeignField.from(0))]);
        }

        if (com.length != elm.length) {
            throw new Error("MSM with invalid comm. and scalar counts");
        }

        let unshifted_len = Math.max(...com.map(pc => pc.unshifted.length));
        let unshifted = [];

        for (let chunk = 0; chunk < unshifted_len; chunk++) {
            let points_and_scalars = com
                .map((c, i) => [c, elm[i]] as [PolyComm<ForeignGroup>, ForeignScalar]) // zip with scalars
                // get rid of scalars that don't have an associated chunk
                .filter(([c, _]) => c.unshifted.length > chunk)
                .map(([c, scalar]) => [c.unshifted[chunk], scalar] as [ForeignGroup, ForeignScalar]);

            // unzip
            let points = points_and_scalars.map(([c, _]) => c);
            let scalars = points_and_scalars.map(([_, scalar]) => scalar);

            let chunk_msm = this.naiveMSM(points, scalars);
            unshifted.push(chunk_msm);
        }

        let shifted_pairs = com
            .map((c, i) => [c.shifted, elm[i]] as [ForeignGroup | undefined, ForeignScalar]) // zip with scalars
            .filter(([shifted, _]) => shifted != null)
            .map((zip) => zip as [ForeignGroup, ForeignScalar]); // zip with scalars

        let shifted = undefined;
        if (shifted_pairs.length != 0) {
            // unzip
            let points = shifted_pairs.map(([c, _]) => c);
            let scalars = shifted_pairs.map(([_, scalar]) => scalar);
            shifted = this.naiveMSM(points, scalars);
        }

        return new PolyComm<ForeignGroup>(unshifted, shifted);
    }

    static chunk_commitment(comm: PolyComm<ForeignGroup>, zeta_n: ForeignScalar): PolyComm<ForeignGroup> {
        let res = comm.unshifted[comm.unshifted.length - 1];

        // use Horner's to compute chunk[0] + z^n chunk[1] + z^2n chunk[2] + ...
        // as ( chunk[-1] * z^n + chunk[-2] ) * z^n + chunk[-3]
        for (const chunk of comm.unshifted.reverse().slice(1)) {
            res = res.scale(zeta_n);
            res = res.add(chunk);
        }
        return new PolyComm([res], comm.shifted);
    }
}

/**
 * Represents a blinded commitment
 */
export class BlindedCommitment<C, S> {
    commitment: PolyComm<C>
    blinders: PolyComm<S>
}

/**
 * Returns the product of all elements of `xs`
 */
export function product(xs: ForeignScalar[]): ForeignScalar {
    return xs.reduce((acc, x) => acc.mul(x), ForeignScalar.from(1));
}

/**
 * Returns (1 + chal[-1] x)(1 + chal[-2] x^2)(1 + chal[-3] x^4) ...
 */
export function bPoly(chals: ForeignScalar[], x: ForeignScalar): ForeignScalar {
    const k = chals.length;

    let prev_x_squared = x;
    let terms = [];
    for (let i = k - 1; i >= 0; i--) {
        terms.push(ForeignScalar.from(1).add(chals[i].mul(prev_x_squared)));
        prev_x_squared = prev_x_squared.mul(prev_x_squared);
    }

    return product(terms);
}

export function bPolyCoefficients(chals: ForeignScalar[]) {
    const rounds = chals.length;
    const s_length = 1 << rounds;

    let s = Array<ForeignScalar>(s_length).fill(ForeignScalar.from(1));
    let k = 0;
    let pow = 1;
    for (let i = 1; i < s_length; i++) {
        k += i === pow ? 1 : 0;
        pow <<= i === pow ? 1 : 0;
        s[i] = s[i - (pow >>> 1)].mul(chals[rounds - 1 - (k - 1)]);
    }

    return s;
}

function combineCommitments(
    evaluations: Evaluation[],
    scalars: ForeignScalar[],
    points: ForeignGroup[],
    polyscale: ForeignScalar,
    randBase: ForeignScalar
): void {
    let xi_i = ForeignScalar.from(1);

    for (const { commitment, degree_bound, ...rest } of evaluations.filter(
        (x) => { return !(x.commitment.unshifted.length === 0) }
    )) {
        // iterating over the polynomial segments
        for (const commCh of commitment.unshifted) {
            scalars.push(randBase.mul(xi_i));
            points.push(commCh);

            xi_i = xi_i.mul(polyscale);
        }

        if (degree_bound !== undefined) {
            const commChShifted = commitment.shifted;
            if (commChShifted !== undefined && !commChShifted.x.equals(0)) {
                // polyscale^i sum_j evalscale^j elm_j^{N - m} f(elm_j)
                scalars.push(randBase.mul(xi_i));
                points.push(commChShifted);

                xi_i = xi_i.mul(polyscale);
            }
        }
    }
}

/**
 * Contains the evaluation of a polynomial commitment at a set of points.
 */
export class Evaluation {
    /** The commitment of the polynomial being evaluated */
    commitment: PolyComm<ForeignGroup>
    /** Contains an evaluation table */
    evaluations: ForeignScalar[][]
    /** optional degree bound */
    degree_bound?: number

    constructor(
        commitment: PolyComm<ForeignGroup>,
        evaluations: ForeignScalar[][],
        degree_bound?: number
    ) {
        this.commitment = commitment;
        this.evaluations = evaluations;
        this.degree_bound = degree_bound;
    }
}

/**
 * Contains the batch evaluation
 */
export class AggregatedEvaluationProof {
    sponge: Sponge
    evaluations: Evaluation[]
    /** vector of evaluation points */
    evaluation_points: Scalar[]
    /** scaling factor for evaluation point powers */
    polyscale: ForeignScalar
    /** scaling factor for polynomials */
    evalscale: ForeignScalar
    /** batched opening proof */
    opening: OpeningProof
    combined_inner_product: ForeignScalar
}

export class OpeningProof {
    /** vector of rounds of L & R commitments */
    lr: [ForeignGroup, ForeignGroup][]
    delta: ForeignGroup
    z1: ForeignScalar
    z2: ForeignScalar
    sg: ForeignGroup

    /**
     * Part of the {@link Provable} interface.
     *
     * Returns the sum of the size in fields of each field of the `OpeningProof` object.
     * 
     * `lr` length is 2
     * 
     * Let `fs` = `ForeignScalar.sizeInFields()`
     * 
     * Let `fg` = `ForeignGroup.sizeInFields()`
     * 
     * So, it returns `2 * fg + fg + fs + fs + fg` which is 30
     */
    static sizeInFields() {
        return 30;
    }

    /**
     * Part of the {@link Provable} interface.
     *
     * Deserializes a {@link OpeningProof} element from a list of field elements.
     * Assumes the following format `[...lr, ...delta, ...z1, ...z2, ...sg]`
     */
    static fromFields(fields: Field[]) {
        const lr0Fields = fields.slice(0, 6);
        const lr1Fields = fields.slice(6, 12);
        const deltaFields = fields.slice(12, 18);
        const z1Fields = fields.slice(18, 21);
        const z2Fields = fields.slice(21, 24);
        const sgFields = fields.slice(24);
        const lr0 = ForeignGroup.fromFields(lr0Fields);
        const lr1 = ForeignGroup.fromFields(lr1Fields);
        const delta = ForeignGroup.fromFields(deltaFields);
        const z1 = ForeignScalar.fromFields(z1Fields);
        const z2 = ForeignScalar.fromFields(z2Fields);
        const sg = ForeignGroup.fromFields(sgFields);

        return { lr: [lr0, lr1], delta, z1, z2, sg };
    }
}
