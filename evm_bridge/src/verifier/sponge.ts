import { Field, Group, Poseidon, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment";

/*
 * Wrapper over o1js' poseidon `Sponge` class which extends its functionality.
 * Currently the sponge operates over the base field (whose elements are represented
 * with the `Field` type).
 */
export class Sponge {
    #internal_sponge

    constructor() {
        this.#internal_sponge = new Poseidon.Sponge();
    }

    absorb(x: Field) {
        this.#internal_sponge.absorb(x);
    }

    squeeze(): Field {
        return this.#internal_sponge.squeeze();
    }

    absorbGroup(g: Group) {
        this.#internal_sponge.absorb(g.x);
        this.#internal_sponge.absorb(g.y);
    }

    absorbGroups(gs: Group[]) {
        gs.forEach(this.absorbGroup);
    }

    /* Will do an operation over the scalar to make it suitable for absorbing */
    absorbScalar(s: Scalar) {
        // this operation was extracted from Kimchi FqSponge's`absorb_fr()`.
        if (Scalar.ORDER < Field.ORDER) {
            const f = Field(s.toBigInt());
            this.absorb(f);

            // INFO: in reality the scalar field is known to be bigger so this won't ever
            // execute, but the code persists for when we have a generic implementation
            // so recursiveness can be achieved.
        } else {
            const s_bigint = s.toBigInt();

            const low = Field(s_bigint && 1n); // LSB
            const high = Field(Number(s_bigint >> 1n)); // rest of the bits
            // WARN: assumes that s_bigint is positive, because >> is the "sign-propagating
            // left shift" operator, so if the number is negative, it'll add 1s instead of 0s.
            // >>>, the "zero-fill left shift" operator should be used instead, but it isnt
            // defined for BigInt as it's always signed (and can't be coarced into an unsigned int).

            this.absorb(high);
            this.absorb(low);
        }
    }

    absorbCommitment(commitment: PolyComm<Group>) {
        this.absorbGroups(commitment.unshifted);
        if (commitment.shifted) this.absorbGroup(commitment.shifted);
    }
}
