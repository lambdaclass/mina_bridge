import { FieldBn254 } from "o1js";
import { pallasCommArrayFromFields, pallasCommFromFields, arrayToFields } from "../field_serializable.js";
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { LookupCommitments } from "./prover.js";

export class ProverCommitments {
    /* Commitments to the witness (execution trace) */
    wComm: PolyComm<ForeignPallas>[]
    /* Commitment to the permutation */
    zComm: PolyComm<ForeignPallas>
    /* Commitment to the quotient polynomial */
    tComm: PolyComm<ForeignPallas>
    /// Commitments related to the lookup argument
    lookup?: LookupCommitments

    constructor(wComm: PolyComm<ForeignPallas>[], zComm: PolyComm<ForeignPallas>, tComm: PolyComm<ForeignPallas>, lookup?: LookupCommitments) {
        this.wComm = wComm;
        this.zComm = zComm;
        this.tComm = tComm;
        this.lookup = lookup;
    }

    static fromFields(fields: FieldBn254[]) {
        let [wComm, zCommOffset] = pallasCommArrayFromFields(fields, 15, 1, 0);
        let [zComm, tCommOffset] = pallasCommFromFields(fields, 1, zCommOffset);
        let [tComm, _] = pallasCommFromFields(fields, 7, tCommOffset);
        //TODO: Add lookup

        return new ProverCommitments(wComm, zComm, tComm);
    }

    toFields() {
        let wComm = arrayToFields(this.wComm);
        let zComm = this.zComm.toFields();
        let tComm = this.tComm.toFields();
        //TODO: Add lookup

        return [...wComm, ...zComm, ...tComm];
    }

    static sizeInFields() {
        let wCommSize = 15 * ForeignPallas.sizeInFields();
        let zCommSize = ForeignPallas.sizeInFields();
        let tCommSize = 7 * ForeignPallas.sizeInFields();
        // TODO: Check lookup size

        return wCommSize + zCommSize + tCommSize;
    }
}
