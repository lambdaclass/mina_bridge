import { Bool, method, SmartContract, State, state } from "snarkyjs";

export class Bridge extends SmartContract {
    @state(Bool) isValidProof = State<Bool>();

    init() {
        super.init();
        this.isValidProof.set(Bool(false));
    }

    @method bridge() {
        this.isValidProof.set(Bool(true));
    }
}
