import { Field, Provable } from "o1js";
import { Sponge } from "../verifier/sponge";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { SRS } from "../SRS.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";

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
    static sub(lhs: PolyComm<ForeignPallas>, rhs: PolyComm<ForeignPallas>): PolyComm<ForeignPallas> {
        let unshifted = [];
        const n1 = lhs.unshifted.length;
        const n2 = rhs.unshifted.length;

        for (let i = 0; i < Math.max(n1, n2); i++) {
            const pt = i < n1 && i < n2 ?
                lhs.unshifted[i].completeAdd(rhs.unshifted[i].negate()) :
                i < n1 ? lhs.unshifted[i] : rhs.unshifted[i];
            unshifted.push(pt);
        }

        let shifted;
        if (lhs.shifted == undefined) shifted = rhs.shifted;
        else if (rhs.unshifted == undefined) shifted = lhs.shifted;
        else shifted = rhs.shifted?.completeAdd(lhs.shifted.negate());

        return new PolyComm(unshifted, shifted);
    }

    /**
     * Scale a commitments
     */
    static scale(v: PolyComm<ForeignPallas>, c: ForeignScalar) {
        return new PolyComm(v.unshifted.map((u) => u.scale(c)), v.shifted?.scale(c));
    }

    /**
    * Execute a simple multi-scalar multiplication
    */
    static naiveMSM(points: ForeignPallas[], scalars: ForeignScalar[]) {
        let result = new ForeignPallas({ x: 0, y: 0 });

        for (let i = 0; i < points.length; i++) {
            let point = points[i];
            let scalar = scalars[i];
            let scaled = point.completeScale(scalar);
            result = result.completeAdd(scaled);
        }

        return result;
    }

    /**
    * Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
    * If empty, returns a commitment with the point at infinity.
    */
    static msm(com: PolyComm<ForeignPallas>[], elm: ForeignScalar[]): PolyComm<ForeignPallas> {
        if (com.length === 0 || elm.length === 0) {
            return new PolyComm<ForeignPallas>([new ForeignPallas({ x: 0, y: 0 })]);
        }

        if (com.length != elm.length) {
            throw new Error("MSM with invalid comm. and scalar counts");
        }

        let unshifted_len = Math.max(...com.map(pc => pc.unshifted.length));
        let unshifted = [];

        for (let chunk = 0; chunk < unshifted_len; chunk++) {
            let points_and_scalars = com
                .map((c, i) => [c, elm[i]] as [PolyComm<ForeignPallas>, ForeignScalar]) // zip with scalars
                // get rid of scalars that don't have an associated chunk
                .filter(([c, _]) => c.unshifted.length > chunk)
                .map(([c, scalar]) => [c.unshifted[chunk], scalar] as [ForeignPallas, ForeignScalar]);

            // unzip
            let points = points_and_scalars.map(([c, _]) => c);
            let scalars = points_and_scalars.map(([_, scalar]) => scalar);

            let chunk_msm = this.naiveMSM(points, scalars);
            unshifted.push(chunk_msm);
        }

        let shifted_pairs = com
            .map((c, i) => [c.shifted, elm[i]] as [ForeignPallas | undefined, ForeignScalar]) // zip with scalars
            .filter(([shifted, _]) => shifted != null)
            .map((zip) => zip as [ForeignPallas, ForeignScalar]); // zip with scalars

        let shifted = undefined;
        if (shifted_pairs.length != 0) {
            // unzip
            let points = shifted_pairs.map(([c, _]) => c);
            let scalars = shifted_pairs.map(([_, scalar]) => scalar);
            shifted = this.naiveMSM(points, scalars);
        }

        return new PolyComm<ForeignPallas>(unshifted, shifted);
    }

    static chunk_commitment(comm: PolyComm<ForeignPallas>, zeta_n: ForeignScalar): PolyComm<ForeignPallas> {
        let res = comm.unshifted[comm.unshifted.length - 1];

        // use Horner's to compute chunk[0] + z^n chunk[1] + z^2n chunk[2] + ...
        // as ( chunk[-1] * z^n + chunk[-2] ) * z^n + chunk[-3]
        for (const chunk of comm.unshifted.reverse().slice(1)) {
            res = res.completeScale(zeta_n);
            res = res.completeAdd(chunk);
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
    return xs.reduce((acc, x) => acc.mul(x).assertAlmostReduced(), ForeignScalar.from(1));
}

/**
 * Returns (1 + chal[-1] x)(1 + chal[-2] x^2)(1 + chal[-3] x^4) ...
 */
export function bPoly(chals: ForeignScalar[], x: ForeignScalar): ForeignScalar {
    const k = chals.length;

    let prev_x_squared = x;
    let terms = [];
    for (let i = k - 1; i >= 0; i--) {
        terms.push(ForeignScalar.from(1).add(chals[i].mul(prev_x_squared)).assertAlmostReduced());
        prev_x_squared = prev_x_squared.mul(prev_x_squared).assertAlmostReduced();
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
        s[i] = s[i - (pow >>> 1)].mul(chals[rounds - 1 - (k - 1)]).assertAlmostReduced();
    }

    return s;
}

function combineCommitments(
    evaluations: Evaluation[],
    scalars: ForeignScalar[],
    points: ForeignPallas[],
    polyscale: ForeignScalar,
    randBase: ForeignScalar
): void {
    let xi_i = ForeignScalar.from(1).assertAlmostReduced();

    for (const { commitment, degree_bound, ...rest } of evaluations.filter(
        (x) => { return !(x.commitment.unshifted.length === 0) }
    )) {
        // iterating over the polynomial segments
        for (const commCh of commitment.unshifted) {
            scalars.push(randBase.mul(xi_i).assertAlmostReduced());
            points.push(commCh);

            xi_i = xi_i.mul(polyscale).assertAlmostReduced();
        }

        if (degree_bound !== undefined) {
            const commChShifted = commitment.shifted;
            if (commChShifted !== undefined && !commChShifted.x.equals(0)) {
                // polyscale^i sum_j evalscale^j elm_j^{N - m} f(elm_j)
                scalars.push(randBase.mul(xi_i).assertAlmostReduced());
                points.push(commChShifted);

                xi_i = xi_i.mul(polyscale).assertAlmostReduced();
            }
        }
    }
}

/**
 * Contains the evaluation of a polynomial commitment at a set of points.
 */
export class Evaluation {
    /** The commitment of the polynomial being evaluated */
    commitment: PolyComm<ForeignPallas>
    /** Contains an evaluation table */
    evaluations: ForeignScalar[][]
    /** optional degree bound */
    degree_bound?: number

    constructor(
        commitment: PolyComm<ForeignPallas>,
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
    evaluation_points: ForeignScalar[]
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
    lr: [ForeignPallas, ForeignPallas][]
    delta: ForeignPallas
    z1: ForeignScalar
    z2: ForeignScalar
    sg: ForeignPallas

    constructor(lr: [ForeignPallas, ForeignPallas][], delta: ForeignPallas, z1: ForeignScalar, z2: ForeignScalar, sg: ForeignPallas) {
        this.lr = lr;
        this.delta = delta;
        this.z1 = z1;
        this.z2 = z2;
        this.sg = sg;
    }

    static #rounds() {
        const { g } = SRS.createFromJSON();
        return Math.ceil(Math.log2(g.length));
    }

    /**
     * Part of the {@link Provable} interface.
     * 
     * Returns the sum of `sizeInFields()` of all the class fields, which depends on `SRS.g` length.
     */
    static sizeInFields() {
        const lrSize = this.#rounds() * 2 * 6;
        const deltaSize = ForeignPallas.provable.sizeInFields();
        const z1Size = ForeignScalar.provable.sizeInFields();
        const z2Size = ForeignScalar.provable.sizeInFields();
        const sgSize = ForeignPallas.provable.sizeInFields();

        return lrSize + deltaSize + z1Size + z2Size + sgSize;
    }

    static fromFields(fields: Field[]) {
        let lr = [];
        // lr_0 = [0...6, 6...12]
        // lr_1 = [12...18, 18...24]
        // lr_2 = [24...30, 30...36]
        // ...
        let rounds = this.#rounds();
        for (let i = 0; i < rounds; i++) {
            let l = ForeignPallas.provable.fromFields(fields.slice(i * 6 * 2, (i * 6 * 2) + 6));
            let r = ForeignPallas.provable.fromFields(fields.slice((i * 6 * 2) + 6, (i * 6 * 2) + (6 * 2)));
            lr.push([l, r]);
        }
        let lrOffset = lr.length * 6 * 2;

        return {
            lr,
            delta: ForeignPallas.provable.fromFields(fields.slice(lrOffset, lrOffset + 6)),
            z1: ForeignScalar.provable.fromFields(fields.slice(lrOffset + 6, lrOffset + 9)),
            z2: ForeignScalar.provable.fromFields(fields.slice(lrOffset + 9, lrOffset + 12)),
            sg: ForeignPallas.provable.fromFields(fields.slice(lrOffset + 12, lrOffset + 18)),
        };
    }

    toFields() {
        let lr: Field[] = [];
        for (const [l, r] of this.lr) {
            lr = lr.concat(ForeignPallas.provable.toFields(l));
            lr = lr.concat(ForeignPallas.provable.toFields(r));
        }
        let z1 = ForeignScalar.provable.toFields(this.z1);
        let z2 = ForeignScalar.provable.toFields(this.z2);

        return [...lr, ...ForeignPallas.provable.toFields(this.delta), ...z1, ...z2, ...ForeignPallas.provable.toFields(this.sg)];
    }

    static toFields(x: OpeningProof) {
        return x.toFields();
    }
}
