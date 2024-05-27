import { FieldBn254 } from "o1js";
import { Sponge } from "../verifier/sponge";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { FieldSerializable, arrayToFields, pallasArrayFromFields, optionalToFields, optionalPallasFromFields } from "../field_serializable.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { OpeningProof } from "./opening_proof";

/**
* A polynomial commitment
*/
export class PolyComm<A extends FieldSerializable> {
    unshifted: A[]
    shifted?: A

    constructor(unshifted: A[], shifted?: A) {
        this.unshifted = unshifted;
        this.shifted = shifted;
    }

    /**
    * Maps over self's `unshifted` and `shifted`
    */
    map<B extends FieldSerializable>(f: (x: A) => B): PolyComm<B> {
        let unshifted = this.unshifted.map(f);
        let shifted = (this.shifted) ? f(this.shifted) : undefined;
        return new PolyComm<B>(unshifted, shifted);
    }

    /**
    * Zips two commitments into one and maps over zipped's `unshifted` and `shifted`
    */
    zip_and_map<B extends FieldSerializable, C extends FieldSerializable>(other: PolyComm<B>, f: (x: [A, B]) => C): PolyComm<C> {
        let unshifted_zip = this.unshifted.map((u, i) => [u, other.unshifted[i]] as [A, B]);
        let shifted_zip = (this.shifted && other.shifted) ?
            [this.shifted, other.shifted] as [A, B] : undefined;
        let unshifted = unshifted_zip.map(f);
        let shifted = shifted_zip ? f(shifted_zip) : undefined;
        return new PolyComm<C>(unshifted, shifted);
    }

    /**
     * Substract two commitments
     */
    static sub(lhs: PolyComm<ForeignPallas>, rhs: PolyComm<ForeignPallas>): PolyComm<ForeignPallas> {
        let unshifted: ForeignPallas[] = [];
        const n1 = lhs.unshifted.length;
        const n2 = rhs.unshifted.length;

        for (let i = 0; i < Math.max(n1, n2); i++) {
            const pt = i < n1 && i < n2 ?
                lhs.unshifted[i].completeAdd(rhs.unshifted[i].negate()) :
                i < n1 ? lhs.unshifted[i] : rhs.unshifted[i];
            unshifted.push(pt as ForeignPallas);
        }

        let shifted: ForeignPallas | undefined;
        if (lhs.shifted == undefined) shifted = rhs.shifted;
        else if (rhs.unshifted == undefined) shifted = lhs.shifted;
        else shifted = rhs.shifted?.completeAdd(lhs.shifted.negate()) as ForeignPallas;

        return new PolyComm<ForeignPallas>(unshifted, shifted);
    }

    /**
     * Scale a commitments
     */
    static scale(v: PolyComm<ForeignPallas>, c: ForeignScalar) {
        return new PolyComm(v.unshifted.map((u) => u.scale(c) as ForeignPallas), v.shifted?.scale(c) as ForeignPallas);
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
            result = result.completeAdd(scaled) as ForeignPallas;
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
            res = res.completeScale(zeta_n) as ForeignPallas;
            res = res.completeAdd(chunk) as ForeignPallas;
        }
        return new PolyComm([res], comm.shifted);
    }

    static fromFields(fields: FieldBn254[], length: number): PolyComm<ForeignPallas> {
        let [unshifted, _] = pallasArrayFromFields(fields, length, 0);

        return new PolyComm(unshifted);
    }

    toFields() {
        return arrayToFields(this.unshifted);
    }

    static sizeInFields(length: number) {
        return ForeignPallas.sizeInFields() * length;
    }
}

/**
 * Represents a blinded commitment
 */
export class BlindedCommitment<C extends FieldSerializable, S extends FieldSerializable> {
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

export function combineCommitments(
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
