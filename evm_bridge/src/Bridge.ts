import { Bool, Field, method, Provable, SmartContract, State, state } from "snarkyjs";

export class Bridge extends SmartContract {
    @state(Bool) isValidProof = State<Bool>();

    init() {
        super.init();
        this.isValidProof.set(Bool(false));
    }

    @method bridge(g: Provable<Field>, z1: Field, sg: Field) {
        this.isValidProof.set(Bool(true));
    }
}
