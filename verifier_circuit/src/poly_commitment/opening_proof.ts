import { SRS } from "../SRS.js";
import { ScalarChallenge } from "../verifier/scalar_challenge.js";
import { invScalar } from "../util/scalar.js";
import { FieldBn254, Provable }  from "o1js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { Sponge } from "../verifier/sponge";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

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
        const lrSize = 2 * 17 * ForeignPallas.sizeInFields();
        const deltaSize = ForeignPallas.sizeInFields();
        const z1Size = ForeignScalar.sizeInFields();
        const z2Size = ForeignScalar.sizeInFields();
        const sgSize = ForeignPallas.sizeInFields();

        return lrSize + deltaSize + z1Size + z2Size + sgSize;
    }

    static fromFields(fields: FieldBn254[]) {
        let lr: [ForeignPallas, ForeignPallas][] = [];
        // lr_0 = [0...6, 6...12]
        // lr_1 = [12...18, 18...24]
        // lr_2 = [24...30, 30...36]
        // ...
        let rounds = this.#rounds();
        for (let i = 0; i < rounds; i++) {
            let l = ForeignPallas.fromFields(fields.slice(i * 6 * 2, (i * 6 * 2) + 6));
            let r = ForeignPallas.fromFields(fields.slice((i * 6 * 2) + 6, (i * 6 * 2) + (6 * 2)));
            lr.push([l, r]);
        }
        let lrOffset = lr.length * 6 * 2;

        return new OpeningProof(
            lr,
            ForeignPallas.fromFields(fields.slice(lrOffset, lrOffset + 6)),
            ForeignScalar.fromFields(fields.slice(lrOffset + 6, lrOffset + 9)),
            ForeignScalar.fromFields(fields.slice(lrOffset + 9, lrOffset + 12)),
            ForeignPallas.fromFields(fields.slice(lrOffset + 12, lrOffset + 18)),
        );
    }

    toFields() {
        let lr: FieldBn254[] = [];
        for (const [l, r] of this.lr) {
            lr = lr.concat(ForeignPallas.toFields(l));
            lr = lr.concat(ForeignPallas.toFields(r));
        }
        let z1 = ForeignScalar.toFields(this.z1);
        let z2 = ForeignScalar.toFields(this.z2);

        return [...lr, ...ForeignPallas.toFields(this.delta), ...z1, ...z2, ...ForeignPallas.toFields(this.sg)];
    }

    static toFields(x: OpeningProof) {
        return x.toFields();
    }

    challenges(
        endo_r: ForeignScalar,
        sponge: Sponge
    ): [ForeignScalar[], ForeignScalar[]] {
        const chal = this.lr.map(([l, r]) => {
            sponge.absorbGroup(l);
            sponge.absorbGroup(r);
            return new ScalarChallenge(sponge.challenge()).toField(endo_r);
        })

        const chal_inv = chal.map(invScalar.bind(this));

        return [chal, chal_inv];
    }
}
