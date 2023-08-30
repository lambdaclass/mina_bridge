import { Bool, Field, method, SmartContract, State, state } from "snarkyjs";

export class Bridge extends SmartContract {
    @state(Bool) isValidProof = State<Bool>();

    init() {
        super.init();
        this.isValidProof.set(Bool(false));
    }

    @method bridge(z1: Field, sg: Field) {
        this.isValidProof.set(Bool(true));
    }
}
