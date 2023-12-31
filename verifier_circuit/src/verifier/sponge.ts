import { Field, ForeignGroup, Group, Poseidon, Provable, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment";
import { PointEvaluations, ProofEvaluations } from "../prover/prover";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

/**
 * Wrapper over o1js' poseidon `Sponge` class which extends its functionality.
 * Currently the sponge operates over the base field (whose elements are represented
 * with the `Field` type).
 */
export class Sponge {
    static readonly HIGH_ENTROPY_LIMBS: number = 2;
    static readonly CHALLENGE_LENGTH_IN_LIMBS: number = 2;

    #internalSponge
    lastSqueezed: bigint[]

    constructor() {
        this.#internalSponge = new Poseidon.Sponge();
        this.lastSqueezed = [];
    }

    absorb(x: Field) {
        this.lastSqueezed = [];
        this.#internalSponge.absorb(x);
    }

    squeezeField(): Field {
        return this.#internalSponge.squeeze();
    }

    absorbGroup(g: ForeignGroup) {
        this.#internalSponge.absorb(Field.fromFields(g.x.toFields()));
        this.#internalSponge.absorb(Field.fromFields(g.y.toFields()));
    }

    absorbGroups(gs: ForeignGroup[]) {
        gs.forEach(this.absorbGroup.bind(this));
        // bind is necessary for avoiding context loss
    }

    /** Will do an operation over the scalar to make it suitable for absorbing */
    absorbScalar(s: ForeignScalar) {
        // this operation was extracted from Kimchi FqSponge's`absorb_fr()`.
        if (Scalar.ORDER < Field.ORDER) {
            const f = Field.fromFields(s.toFields());
            this.absorb(f);

            // INFO: in reality the scalar field is known to be bigger so this won't ever
            // execute, but the code persists for when we have a generic implementation
            // so recursiveness can be achieved.
        } else {
            const high = Provable.witness(Field, () => {
                const s_bigint = s.toBigInt();
                const bits = BigInt(s_bigint.toString(2).length);

                const high = Field((s_bigint >> 1n) & ((1n << (bits - 1n)) - 1n)); // remaining bits

                return high;
            });

            const low = Provable.witness(Field, () => {
                const s_bigint = s.toBigInt();

                const low = Field(s_bigint & 1n); // LSB

                return low;
            });

            // WARN: be careful when s_bigint is negative, because >> is the "sign-propagating
            // left shift" operator, so if the number is negative, it'll add 1s instead of 0s.
            // >>>, the "zero-fill left shift" operator should be used instead, but it isnt
            // defined for BigInt as it's always signed (and can't be coarced into an unsigned int).
            // TODO: test that the mask works correctly.

            this.absorb(high);
            this.absorb(low);
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
            const remaining = this.lastSqueezed.slice(0, numLimbs);

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
        return Provable.witness(ForeignScalar, () => {
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
        return Provable.witness(ForeignScalar, () => {
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
