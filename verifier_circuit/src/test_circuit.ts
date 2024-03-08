import { Circuit, Field, circuitMain, public_ } from 'o1js';

export class TestCircuit extends Circuit {
    @circuitMain
    static main(@public_ a: Field) {
        a.assertEquals(Field.from(5));
    }
}
