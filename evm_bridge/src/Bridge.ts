import { Bool, Field, MerkleMap, method, SmartContract, State, state } from "snarkyjs";
import { SRSWindow } from "./SRS.js";

export class Bridge extends SmartContract {
    @state(Bool) isValidProof = State<Bool>();

    init() {
        super.init();
        this.isValidProof.set(Bool(false));
    }

    @method bridge(s: SRSWindow, z1: Field, sg: Field) {
        this.isValidProof.set(Bool(true));
    }
}
