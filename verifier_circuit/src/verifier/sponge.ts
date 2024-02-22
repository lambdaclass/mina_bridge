import { Field, ForeignGroup, Poseidon, Provable, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment";
import { PointEvaluations, ProofEvaluations } from "../prover/prover";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { ForeignField } from "../foreign_fields/foreign_field.js";
import { assert } from "console";

type UnionForeignField = ForeignField | ForeignScalar;
type UnionForeignFieldArr = ForeignField[] | ForeignScalar[];
type UnionForeignFieldMatrix = ForeignField[][] | ForeignScalar[][];

enum SpongeMode {
    Squeezing,
    Absorbing
}

export class ArithmeticSponge {
    params: ArithmeticSpongeParams
    state: UnionForeignFieldArr
    mode: SpongeMode
    offset: number

    constructor(params: ArithmeticSpongeParams) {
        this.params = params;
        this.state = new Array(params.rate);
        this.offset = 0;
    }

    absorb(elem: UnionForeignField) {
        if (this.mode === SpongeMode.Squeezing) {
            this.mode = SpongeMode.Absorbing;
            this.offset = 0;
        } else if (this.offset === this.params.rate) {
            this.#permutation();
            this.offset = 0;
        }

        this.state[this.offset] = this.state[this.offset].add(elem);
        this.offset++;
    }

    squeeze(): UnionForeignField {
        if (this.mode == SpongeMode.Absorbing || this.offset === this.params.rate) {
            this.mode = SpongeMode.Squeezing;
            this.#permutation();
            this.offset = 0;
        }

        return this.state[this.offset++];
    }

    // permutation algorithms

    #sbox(element: UnionForeignField): UnionForeignField {
        // return element^7
        let element_squared = element.mul(element); // ^2
        let element_fourth = element_squared.mul(element_squared); // ^4
        let element_sixth = element_fourth.mul(element_squared); // ^6
        return element_sixth.mul(element);
    }

    #applyMds(): UnionForeignFieldArr {
        let n = this.params.mds[0].length;
        assert(n == this.state.length);

        // matrix-vector product: mds * state
        return this.params.mds.map((row) =>
            this.state.reduce((acc, s, i) => acc.add(s.mul(row[i])))
        );
    }

    #applyRound(round: number) {
        // sbox
        this.state = this.state.map(this.#sbox);

        // apply mds
        this.state = this.#applyMds();

        // add round constant
        this.state = this.state.map((s, i) => s.add(this.params.round_constants[round][i]));
    }

    #permutation() {
        let round_offset = 0;
        if (this.params.ark_initial) {
            let constant = this.params.round_constants[0];
            this.state = this.state.map((s, i) => s.add(constant[i]));
            round_offset = 1;
        }

        for (let round = 0; round < this.params.rounds; round++) {
            this.#applyRound(round + round_offset);
        }
    }
}


export class ArithmeticSpongeParams {
    mds: UnionForeignFieldMatrix
    round_constants: UnionForeignFieldMatrix
    ark_initial: boolean
    rounds: number
    rate: number
}

/**
 * Wrapper over o1js' poseidon `Sponge` class which extends its functionality.
 * Currently the sponge operates over the emulated base field (whose elements are 
 * represented with the `ForeignField` type).
 */
export class Sponge {
    static readonly HIGH_ENTROPY_LIMBS: number = 2;
    static readonly CHALLENGE_LENGTH_IN_LIMBS: number = 2;

    #internalSponge
    lastSqueezed: bigint[] // these are 64 bit limbs

    constructor() {
        this.#internalSponge = new Poseidon.ForeignSponge(ForeignField.modulus);
        this.lastSqueezed = [];
    }

    absorb(x: ForeignField) {
        this.lastSqueezed = [];
        this.#internalSponge.absorb(x);
    }

    squeezeField(): ForeignField {
        return this.#internalSponge.squeeze();
    }

    absorbGroup(g: ForeignGroup) {
        this.#internalSponge.absorb(g.x);
        this.#internalSponge.absorb(g.y);
    }

    absorbGroups(gs: ForeignGroup[]) {
        gs.forEach(this.absorbGroup.bind(this));
        // bind is necessary for avoiding context loss
    }

    /** Will do an operation over the scalar to make it suitable for absorbing */
    absorbScalar(s: ForeignScalar) {
        // this operation was extracted from Kimchi FqSponge's`absorb_fr()`.
        if (ForeignScalar.modulus < ForeignField.modulus) {
            const f = ForeignField.from(s.toBigInt());
            this.absorb(f);
        } else {
            const high_bits = Provable.witnessBn254(ForeignField, () => {
                return ForeignField.from(s.toBigInt() >> 1n);
                // WARN:  >> is the "sign-propagating left shift" operator, so if the number is negative,
                // it'll add 1s instead of 0s to the most significant end of the integer.
                // >>>, the "zero-fill left shift" operator should be used instead here, but it isnt
                // defined for BigInt as it's always signed (and can't be coarced into an unsigned int).
                // In any way, the integers are always positive, so there's no problem here.
            });

            const low_bit = Provable.witnessBn254(ForeignField, () => {
                return ForeignField.from(s.toBigInt() & 1n);
            });


            this.absorb(high_bits);
            this.absorb(low_bit);
        }
    }

    absorbScalars(s: ForeignScalar[]) {
        this.lastSqueezed = [];
        s.forEach(this.absorbScalar.bind(this));
    }

    absorbCommitment(commitment: PolyComm<ForeignGroup>) {
        this.absorbGroups(commitment.unshifted);
        if (commitment.shifted) this.absorbGroup(commitment.shifted);
    }

    absorbEvals(evals: ProofEvaluations<PointEvaluations<ForeignScalar[]>>) {
        const {
            public_input,
            w,
            z,
            s,
            coefficients,
            //lookup,
            genericSelector,
            poseidonSelector
        } = evals;
        let points = [
            z,
            genericSelector,
            poseidonSelector,
        ]
        // arrays:
        points = points.concat(w);
        points = points.concat(s);
        points = points.concat(coefficients);

        // optional:
        if (public_input) points.push(public_input);
        //if (lookup) points.push(lookup); // FIXME: ignoring lookups

        points.forEach((p) => {
            this.absorbScalars.bind(this)(p.zeta);
            this.absorbScalars.bind(this)(p.zetaOmega);
        });
    }

    /**
    * This squeezes until `numLimbs` 64-bit high entropy limbs are retrieved.
    */
    squeezeLimbs(numLimbs: number): bigint[] { // will return limbs of 64 bits.
        if (this.lastSqueezed.length >= numLimbs) {
            const limbs = this.lastSqueezed.slice(0, numLimbs);
            const remaining = this.lastSqueezed.slice(numLimbs + 1, this.lastSqueezed.length);

            this.lastSqueezed = remaining;
            return limbs;
        } else {
            let x = this.#internalSponge.squeeze().toBigInt();

            let xLimbs = [];
            let mask = (1n << 64n) - 1n; // highest 64 bit value
            for (let _ = 0; _ <= Sponge.HIGH_ENTROPY_LIMBS; _++) {
                xLimbs.push(x & mask); // 64 bits limbs, least significant first
                x >>= 64n;
            }
            this.lastSqueezed = this.lastSqueezed.concat(xLimbs);
            return this.squeezeLimbs(numLimbs);
        }
    }

    /**
    * Calls `squeezeLimbs()` and composes them into a scalar.
    */
    squeeze(numLimbs: number): ForeignScalar {
        return Provable.witnessBn254(ForeignScalar, () => {
            let squeezed = 0n;
            const squeezedLimbs = this.squeezeLimbs(numLimbs);
            for (const i in this.squeezeLimbs(numLimbs)) {
                squeezed += squeezedLimbs[i] << (64n * BigInt(i));
            }
            return ForeignScalar.from(squeezed);
        });
    }

    challenge(): ForeignScalar {
        return this.squeeze(Sponge.CHALLENGE_LENGTH_IN_LIMBS);
    }

    digest(): ForeignScalar {
        return Provable.witnessBn254(ForeignScalar, () => {
            const x = this.squeezeField().toBigInt();
            const result = x < Scalar.ORDER ? x : 0;
            // Comment copied from Kimchi's codebase:
            //
            // Returns zero for values that are too large.
            // This means that there is a bias for the value zero (in one of the curve).
            // An attacker could try to target that seed, in order to predict the challenges u and v produced by the Fr-Sponge.
            // This would allow the attacker to mess with the result of the aggregated evaluation proof.
            // Previously the attacker's odds were 1/q, now it's (q-p)/q.
            // Since log2(q-p) ~ 86 and log2(q) ~ 254 the odds of a successful attack are negligible.
            return ForeignScalar.from(result);
        });
    }
}
