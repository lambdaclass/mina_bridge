import { Bool, method, Proof, SelfProof, SmartContract, State, state, ZkappPublicInput } from "snarkyjs";

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
