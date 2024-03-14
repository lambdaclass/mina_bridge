import { ProvableBn254 } from "o1js"
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";
import { Sponge } from "./sponge.js";
import { getLimbs64 } from "../util/bigint.js";

export class ScalarChallenge {
    chal: ForeignScalar

    constructor(chal: ForeignScalar) {
        this.chal = chal;
    }

    toFieldWithLength(length_in_bits: number, endo_coeff: ForeignScalar): ForeignScalar {
        let result = ForeignScalar.from(0).assertAlmostReduced();

        ProvableBn254.asProver(() => {
            const rep = this.chal.toBigInt();
            const rep_64_limbs = getLimbs64(rep);

            let a = ForeignScalar.from(2).assertAlmostReduced();
            let b = ForeignScalar.from(2).assertAlmostReduced();

            const one = ForeignScalar.from(1);
            const negone = one.neg();
            for (let i = Math.floor(length_in_bits / 2) - 1; i >= 0; i--) {
                a = a.add(a).assertAlmostReduced();
                b = b.add(b).assertAlmostReduced();

                const r_2i = getBit(rep_64_limbs, 2 * i);
                const s = r_2i === 0n ? negone : one;

                if (getBit(rep_64_limbs, 2 * i + 1) === 0n) {
                    b = b.add(s).assertAlmostReduced();
                } else {
                    a = a.add(s).assertAlmostReduced();
                }
            }

            result = a.mul(endo_coeff).add(b).assertAlmostReduced();
        });

        return result;
    }

    toField(endo_coeff: ForeignScalar): ForeignScalar {
        const length_in_bits = 64 * Sponge.CHALLENGE_LENGTH_IN_LIMBS;
        return this.toFieldWithLength(length_in_bits, endo_coeff);
    }
}

function getBit(limbs_lsb: bigint[], i: number): bigint {
    const limb = Math.floor(i / 64);
    const j = BigInt(i % 64);
    return (limbs_lsb[limb] >> j) & 1n;
    // FIXME: if it's negative, then >> will fill with ones
}

