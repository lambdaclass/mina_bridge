import {
    Field,
    SmartContract,
    state,
    State,
    method
} from 'snarkyjs';

export class Addition extends SmartContract {
    @state(Field) num = State<Field>();

    // initialize the state of the contract
    init() {
        super.init();
        this.num.set(Field(0));
    }

    // generates a zk proof
    @method update(operand: Field) {
        // reads the value from the blockchain
        const currentState = this.num.get();
        this.num.assertEquals(currentState);

        // writes the new value to the blockchain
        this.num.set(currentState.add(operand));
    }
}
