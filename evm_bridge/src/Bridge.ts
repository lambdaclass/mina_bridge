import { Bool, Field, MerkleMap, method, SmartContract, State, state } from "snarkyjs";
import { SRS } from "./SRS.js";

export class Bridge extends SmartContract {
    @state(Bool) isValidProof = State<Bool>();

    init() {
        super.init();
        this.isValidProof.set(Bool(false));
    }

    @method bridge(s: SRS, z1: Field, sg: Field) {
        this.isValidProof.set(Bool(true));
    }
}
