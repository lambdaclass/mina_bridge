import {
    Field,
    SmartContract,
    state,
    State,
    method
} from 'snarkyjs';

export class Addition extends SmartContract {
    @state(Field) num = State<Field>();

    init() {
        super.init();
        this.num.set(Field(0));
    }

    @method update(operand: Field) {
        const currentState = this.num.get();
        this.num.assertEquals(currentState);
        this.num.set(currentState.add(operand));
    }
}
